//
//  Stormcloud.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit
import CoreData

protocol StormcloudDocument {
	var backupMetadata : StormcloudMetadata? {
		get set
	}
}


public typealias StormcloudDocumentClosure = (_ error : StormcloudError?, _ metadata : StormcloudMetadata?) -> ()

public protocol StormcloudRestoreDelegate {
	func stormcloud( stormcloud : Stormcloud, shouldRestore objects: [String : AnyObject], toEntityWithName name: String ) -> Bool
}

enum StormcloudEntityKeys : String {
	case EntityType = "com.voyagetravelapps.Stormcloud.entityType"
	case ManagedObject = "com.voyagetravelapps.Stormcloud.managedObject"
}

// Keys for NSUSserDefaults that manage iCloud state
enum StormcloudPrefKey : String {
	case iCloudToken = "com.voyagetravelapps.Stormcloud.iCloudToken"
	case isUsingiCloud = "com.voyagetravelapps.Stormcloud.usingiCloud"
	
}

/**
*  Informs the delegate of changes made to the metadata list.
*/
public protocol StormcloudDelegate {
	func metadataListDidChange(_ manager : Stormcloud)
	func metadataListDidAddItemsAt( _ addedItems : IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type : StormcloudDocumentType)
}

struct StormcloudStore {
	let type : StormcloudDocumentType
	var items : [StormcloudMetadata] = []
}

extension Stormcloud : DocumentProviderDelegate {
	func provider(_ prov: DocumentProvider, didDelete item: URL) {
		
	}
	func provider(_ prov: DocumentProvider, didFindItems items: [StormcloudDocumentType : [StormcloudMetadata]]) {

		for type in StormcloudDocumentType.allTypes() {
			guard var hasItems = items[type] else {
				continue
			}
			hasItems.sort { (item1, item2) -> Bool in
				return item1.date > item2.date
			}
			let previousItems : [StormcloudMetadata]
			if let hasPreviousItems = internalList[type] {
				previousItems = hasPreviousItems
			} else {
				previousItems = []
			}
			
			let deletedItems = previousItems.filter { (metadata) -> Bool in
				if hasItems.contains(metadata) {
					return false
				}
				return true
			}

			var deletedItemsIndices : IndexSet? = IndexSet()
			for item in deletedItems {
				if let hasIdx = previousItems.index(of: item) {
					deletedItemsIndices?.insert(hasIdx)
					stormcloudLog("Item to delete: \(item) at \(hasIdx)")
				}
				
			}
			
			let addedItems = hasItems.filter { (url) -> Bool in
				if previousItems.contains(url) {
					return false
				}
				return true
			}
			internalList[type] = hasItems
			
			var addedItemsIndices : IndexSet? = IndexSet()
			for item in addedItems {
				if let didAddItems = internalList[type]!.index(of: item) {
					addedItemsIndices?.insert(didAddItems)
					stormcloudLog("Item added at \(didAddItems)")
				}
			}
			
			addedItemsIndices = (addedItemsIndices?.count == 0) ? nil : addedItemsIndices
			deletedItemsIndices = (deletedItemsIndices?.count == 0) ? nil : deletedItemsIndices
			self.delegate?.metadataListDidAddItemsAt(addedItemsIndices, andDeletedItemsAt: deletedItemsIndices, for: type)
		}

	}
}

open class Stormcloud: NSObject {
	
	/// Whether or not the backup manager is currently using iCloud (read only)
	open var isUsingiCloud : Bool {
		get {
			return UserDefaults.standard.bool(forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		}
	}
	

	/// The backup manager delegate
	open var delegate : StormcloudDelegate?
	open var coreDataDelegate : StormcloudCoreDataDelegate?
	
	open var shouldDisableInProgressCheck : Bool = false
	
	var formatter = DateFormatter()
	
	var workingCache : [String : Any] = [:]
	
	var iCloudURL : URL?
	var metadataQuery : NSMetadataQuery = NSMetadataQuery()
	
	var internalList : [StormcloudDocumentType : [StormcloudMetadata]] = [:]
	var metadataLists : [StormcloudDocumentType : StormcloudStore] = [:]
	var internalQueryList : [String : StormcloudMetadata] = [:]
	var pauseMetadata : Bool = false
	
	var moveDocsToiCloud : Bool = false
	var moveDocsToiCloudCompletion : ((_ error : StormcloudError?) -> Void)?
	
	var operationInProgress : Bool = false
	
	var restoreDelegate : StormcloudRestoreDelegate?
	
	var provider : DocumentProvider?
	
	@objc public override init() {
		super.init()
		if self.isUsingiCloud {
			if let hasIcloud = iCloudDocumentProvider() {
				provider = hasIcloud
			}
			
			// TODO: Review
			_ = self.enableiCloudShouldMoveLocalDocumentsToiCloud(false, completion: nil)
		}
		
		if provider == nil {
			provider = LocalDocumentProvider()
		}
		provider?.delegate = self
		provider?.updateFiles()
		
		// Assume UTC for everything.
		self.formatter.timeZone = TimeZone(identifier: "UTC")
		
		// TODO: Review
		self.prepareDocumentList()
	}
	
	/**
	Reloads the current metadata list, either from iCloud or from local documents. If you are switching between storage locations, using the appropriate methods will automatically reload the list of documents so there's no need to call this.
	*/
	@objc open func reloadData() {
		self.prepareDocumentList()
	}
	
	open func items( for type: StormcloudDocumentType ) -> [StormcloudMetadata] {
		if let hasItems = internalList[type] {
			return hasItems
		}
		return []
//		return internalMetadataList.filter({ (metadata) -> Bool in
//			switch type {
//			case .jpegImage:
//				return metadata is JPEGMetadata
//			case .json:
//				return metadata is JSONMetadata
//			case .pngImage:
//				return false
//			case .unknown:
//				return false
//			}
//		})
	}
	
	/**
	Attempts to enable iCloud for document storage.
	
	- parameter move: Attept to move the documents from local storage to iCloud
	- parameter completion: A completion handler to be run when the move has finisehd
	
	- returns: true if iCloud was enabled, false otherwise
	*/
	open func enableiCloudShouldMoveLocalDocumentsToiCloud(_ move : Bool, completion : ((_ error : StormcloudError?) -> Void)? ) -> Bool {
		let currentiCloudToken = FileManager.default.ubiquityIdentityToken
		
		// If we don't have a token, then we can't enable iCloud
		guard let token = currentiCloudToken  else {
			completion?(StormcloudError.iCloudUnavailable)
			disableiCloudShouldMoveiCloudDocumentsToLocal(false, completion: nil)
			return false
		
		}
		// Add observer for iCloud user changing
		NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.iCloudUserChanged(_:)), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
		
		let data = NSKeyedArchiver.archivedData(withRootObject: token)
		UserDefaults.standard.set(data, forKey: StormcloudPrefKey.iCloudToken.rawValue)
		UserDefaults.standard.set(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		
		// Make a note that we need to move documents once iCloud is initialised
		self.moveDocsToiCloud = move
		self.moveDocsToiCloudCompletion = completion
		
		self.prepareDocumentList()
		return true
	}
	
	/**
	Disables iCloud in favour of local storage
	
	- parameter move:       Pass true if you want the manager to attempt to copy any documents in iCloud to local storage
	- parameter completion: A completion handler to run when the attempt to copy documents has finished.
	*/
	open func disableiCloudShouldMoveiCloudDocumentsToLocal( _ move : Bool, completion : ((_ moveSuccessful : Bool) -> Void)? ) {
		
		if move {
			// Handle the moving of documents
			self.moveItemsFromiCloud(self.metadataLists, completion: completion)
		}
		
		UserDefaults.standard.removeObject(forKey: StormcloudPrefKey.iCloudToken.rawValue)
		UserDefaults.standard.set(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		
		self.metadataQuery.stop()
		self.internalQueryList.removeAll()
		self.prepareDocumentList()
	}
	
	func moveItemsToiCloud( _ items : [String], completion : ((_ success : Bool, _ error : NSError?) -> Void)? ) {
		if let docsDir = self.documentsDirectory(), let iCloudDir = iCloudDocumentsDirectory() {
			
			DispatchQueue.global(qos: .default).async {
				var success = true
				var hasError : NSError?
				for filename in items {
					let finalURL = docsDir.appendingPathComponent(filename)
					let finaliCloudURL = iCloudDir.appendingPathComponent(filename)
					do {
						try FileManager.default.setUbiquitous(true, itemAt: finalURL, destinationURL: finaliCloudURL)
					} catch let error as NSError {
						success = false
						hasError = error
					}
				}
				
				DispatchQueue.main.async(execute: { () -> Void in
					completion?(success, hasError)
				})
			}
			
		} else {
			let scError = StormcloudError.couldntMoveDocumentToiCloud
			let error = scError.asNSError()
			completion?(false, error)
		}
	}
	
	func moveItemsFromiCloud( _ items : [StormcloudDocumentType :  StormcloudStore], completion : ((_ success : Bool ) -> Void)? ) {
		// Our current provider should be an iCloud Document Provider
		guard let currentProvider = provider as? iCloudDocumentProvider else {
			completion?(false)
			return
		}
		
		// get a reference to a local one
		let localProvider = LocalDocumentProvider()
		guard let docsDir = localProvider.documentsDirectory(), let iCloudDir = currentProvider.documentsDirectory() else {
			completion?(false)
			return
		}
		
		// Set the provider to our new local provider so it can respond to changes
		self.provider = localProvider
			
		var filenames = [String]()
		for item in items {
			let allNames = item.value.items.map() { $0.filename }
			filenames.append(contentsOf: allNames )
		}
		
		DispatchQueue.global(qos: .default).async {
			var success = true
			for element in filenames {
				let finalURL = docsDir.appendingPathComponent(element)
				let finaliCloudURL = iCloudDir.appendingPathComponent(element)
				do {
					self.stormcloudLog("Moving files from iCloud: \(finaliCloudURL) to local URL: \(finalURL)")
					try FileManager.default.setUbiquitous(false, itemAt: finaliCloudURL, destinationURL: finalURL)
				} catch {
					success = false
				}
			}
			
			DispatchQueue.main.async(execute: { () -> Void in
//					self.prepareDocumentList()
				completion?(success)
				
			})
		}
	}
	
	
	@objc func iCloudUserChanged( _ notification : Notification ) {
		// Handle user changing
//		self.prepareDocumentList()
	}
	
	deinit {
		self.metadataQuery.stop()
		NotificationCenter.default.removeObserver(self)
	}
	
}



// MARK: - Helper methods

extension Stormcloud {
	/**
	Gets the URL for a given StormcloudMetadata item. Will return either the local or iCloud URL.
	
	- parameter item: The item to get the URL for
	
	- returns: An optional NSURL, giving the location for the item
	*/
	public func urlForItem(_ item : StormcloudMetadata) -> URL? {
		return self.provider?.documentsDirectory()?.appendingPathComponent(item.filename)
	}
}

// MARK: - Adding Documents
extension Stormcloud {
	
	public func addDocument( withData objects : Any, for documentType : StormcloudDocumentType,  completion: @escaping StormcloudDocumentClosure ) {
		self.stormcloudLog("\(#function)")
		
		if self.operationInProgress {
			completion(.backupInProgress, nil)
			return
		}
		self.operationInProgress = true
		
		// Find out where we should be savindocumentsDirectoryg, based on iCloud or local
		if let baseURL = self.documentsDirectory() {
			// Set the file extension to whatever it is we're trying to back up
			let metadata : StormcloudMetadata
			let document : UIDocument
			let finalURL : URL
			switch documentType {
			case .jpegImage:
				
				metadata = JPEGMetadata()
				finalURL = baseURL.appendingPathComponent(metadata.filename)
				let imageDocument = ImageDocument(fileURL: finalURL )
				if let isImage = objects as? UIImage {
					imageDocument.imageToBackup = isImage
				}
				document = imageDocument
			case .json:
				metadata = JSONMetadata()
				finalURL = baseURL.appendingPathComponent(metadata.filename)
				let jsonDocument = JSONDocument(fileURL: finalURL )
				jsonDocument.objectsToBackup = objects
				document = jsonDocument
			default:
				metadata  = StormcloudMetadata()
				finalURL = baseURL.appendingPathComponent(metadata.filename)
				document = UIDocument()
			}
			
			
			self.stormcloudLog("Backing up to: \(finalURL)")
			
			// If the filename already exists, can't create a new document. Usually because it's trying to add them too quickly.
			let exists = self.metadataLists[documentType]!.items.filter({ (element) -> Bool in
				if element.filename == metadata.filename {
					return true
				}
				return false
			})
			
			if exists.count > 0 {
				completion(.backupFileExists, nil)
				return
			}
			document.save(to: finalURL, for: .forCreating, completionHandler: { (success) -> Void in
				let totalSuccess = success
				
				if ( !totalSuccess ) {
					
					self.stormcloudLog("\(#function): Error saving new document")
					
					DispatchQueue.main.async(execute: { () -> Void in
						self.operationInProgress = false
						completion(StormcloudError.couldntSaveNewDocument, nil)
					})
					return
					
				}
				document.close(completionHandler: nil)
				if !self.isUsingiCloud {
					DispatchQueue.main.async(execute: { () -> Void in
						self.metadataLists[documentType]!.items.append(metadata)

						self.operationInProgress = false
						completion(nil, (totalSuccess) ? metadata : metadata)
					})
				} else {
					DispatchQueue.main.async(execute: { () -> Void in
						self.moveItemsToiCloud([metadata.filename], completion: { (success, error) -> Void in
							self.operationInProgress = false
							if totalSuccess {
								completion(nil, metadata)
							} else {
								completion(StormcloudError.couldntMoveDocumentToiCloud, metadata)
							}
						})
					})
				}
			})
		}
	}
}

// MARK: - Restoring

extension Stormcloud {
	
	
	/**
	Restores a JSON object from the given Stormcloud Metadata object
	
	- parameter metadata:        The Stormcloud metadata object that represents the document
	- parameter completion:      A completion handler to run when the operation is completed
	*/
	public func restoreBackup(withMetadata metadata : StormcloudMetadata, completion : @escaping (_ error: StormcloudError?, _ restoredObjects : Any? ) -> () ) {
		
		
		guard let metadataList = metadataLists[metadata.type]?.items else {
			completion(.invalidDocumentData, nil)
			return
		}
		
		if metadataList.contains(metadata) {
			if let idx = metadataList.index(of: metadata) {
				metadata.iCloudMetadata = metadataList[idx].iCloudMetadata
			}
			
		}
		
		if self.operationInProgress && !self.shouldDisableInProgressCheck {
			completion(.backupInProgress, nil)
			return
		}
		
		guard let url = self.urlForItem(metadata) else {
			self.operationInProgress = false
			completion(.invalidURL, nil)
			return
		}
		if !self.shouldDisableInProgressCheck {
			self.operationInProgress = true
		}
		
		let document : UIDocument
		
		switch metadata.type {
		case .jpegImage:
			document = ImageDocument(fileURL: url)
		default:
			document = JSONDocument(fileURL: url)
		}
		
		let _ = document.documentState
		document.open(completionHandler: { (success) -> Void in
			var error : StormcloudError? = nil
			
			let data : Any?
			if let isJSON = document as? JSONDocument, let hasObjects = isJSON.objectsToBackup {
				data = hasObjects
			} else if let isImage = document as? ImageDocument, let hasImage = isImage.imageToBackup {
				data = hasImage
			} else {
				data = nil
				error = StormcloudError.invalidDocumentData
			}
			
			if !success {
				error = StormcloudError.couldntOpenDocument
			}
			
			DispatchQueue.main.async(execute: { () -> Void in
				self.operationInProgress = false
				self.shouldDisableInProgressCheck = false
				completion(error, data)
				document.close()
			})
		})
	}
	
	public func deleteItems(_ type : StormcloudDocumentType, overLimit limit : Int, completion : @escaping ( _ error : StormcloudError? ) -> () ) {
		
		// Knock one off as we're about to back up
		var itemsToDelete : [StormcloudMetadata] = []
		
		guard let validItems = metadataLists[type]?.items else {
			completion(.invalidDocumentData)
			return
		}
		
		if limit > 0 && validItems.count > limit {
			for i in limit..<validItems.count {
				let metadata = validItems[i]
				itemsToDelete.append(metadata)
			}
		}
		
		for item in itemsToDelete {
			self.deleteItem(item, completion: { (index, error) -> () in
				if let hasError = error {
					self.stormcloudLog("Error deleting: \(hasError.localizedDescription)")
					completion(.couldntDelete)
				} else {
					completion(nil)
				}
			})
		}
		
	}
	
	public func deleteItems( _ metadataItems : [StormcloudMetadata], completion : @escaping (_ index : Int?, _ error : NSError? ) -> () ) {
		
		// Pull them out of the internal list first
		var deleteList : [ StormcloudDocumentType : Int ] = [:]
		var urlList : [ URL : Int ] = [:]
		var errorList : [StormcloudMetadata] = []
		for item in metadataItems {
			if let itemURL = self.urlForItem(item), let idx = metadataLists[item.type]?.items.index(of: item) {
				urlList[itemURL] = idx
				deleteList[item.type] = idx
			} else {
				errorList.append(item)
			}
		}
		
		for (type, idx) in deleteList {
			metadataLists[type]!.items.remove(at: idx)
		}
		
		// Remove them from the internal list
		DispatchQueue.global(qos: .default).async {
			
			// TESTING ENVIRONMENT
			if StormcloudEnvironment.MangleDelete.isEnabled() {
				sleep(2)
				DispatchQueue.main.async(execute: { () -> Void in
					let deleteError = StormcloudError.couldntDelete
					let error = NSError(domain:deleteError.domain(), code: deleteError.rawValue, userInfo: nil)
					completion(nil, error )
				})
				return
			}
			// ENDs
			var hasError : NSError?
			for (url, _) in urlList {
				let coordinator = NSFileCoordinator(filePresenter: nil)
				coordinator.coordinate(writingItemAt: url, options: .forDeleting, error:nil, byAccessor: { (url) -> Void in
					
					do {
						try FileManager.default.removeItem(at: url)
					} catch let error as NSError  {
						hasError = error
					}
					
				})
				
				if hasError != nil {
					break
				}
				
			}
			DispatchQueue.main.async(execute: { () -> Void in
				completion(nil, hasError)
			})
		}
	}
	
	/**
	Deletes the document represented by the metadataItem object
	
	- parameter metadataItem: The Stormcloud Metadata object that represents the document
	- parameter completion:   The completion handler to run when the delete completes
	*/
	public func deleteItem(_ metadataItem : StormcloudMetadata, completion : @escaping (_ index : Int?, _ error : NSError?) -> () ) {
		self.deleteItems([metadataItem], completion: completion)
	}
}


extension Stormcloud {
	func stormcloudLog( _ string : String ) {
		if StormcloudEnvironment.VerboseLogging.isEnabled() {
			print(string)
		}
	}
}



