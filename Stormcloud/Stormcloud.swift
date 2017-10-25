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

public protocol StormcloudRestoreDelegate : class {
	func stormcloud( stormcloud : Stormcloud, shouldRestore objects: [String : AnyObject], toEntityWithName name: String ) -> Bool
}

enum StormcloudEntityKeys : String {
	case EntityType = "com.voyagetravelapps.Stormcloud.entityType"
	case ManagedObject = "com.voyagetravelapps.Stormcloud.managedObject"
}

// Keys for NSUSserDefaults that manage iCloud state
public enum StormcloudPrefKey : String {
	case isUsingiCloud = "com.voyagetravelapps.Stormcloud.usingiCloud"
}

/**
*  Informs the delegate of changes made to the metadata list.
*/
public protocol StormcloudDelegate : class {
	func metadataDidUpdate( _ metadata : StormcloudMetadata, for type : StormcloudDocumentType)
	func metadataListDidChange(_ manager : Stormcloud)
	func metadataListDidAddItemsAt( _ addedItems : IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type : StormcloudDocumentType)
	func stormcloudFileListDidLoad( _ stormcloud : Stormcloud)
}

extension Stormcloud : DocumentProviderDelegate {
	func provider(_ prov: DocumentProvider, didDelete item: URL) {
		
	}
	func provider(_ prov: DocumentProvider, didFindItems items: [StormcloudDocumentType : [StormcloudMetadata]]) {
		if !fileListLoaded {
			self.delegate?.stormcloudFileListDidLoad(self)
			fileListLoadedInternal = true
			operationInProgress = false
		}
		
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
			
			internalList[type]?.forEach({ (metadata) in
				if metadata.iCloudMetadata != nil {
					self.delegate?.metadataDidUpdate(metadata, for: type)
				}
			})
			
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
	open weak var delegate : StormcloudDelegate?
	open var coreDataDelegate : StormcloudCoreDataDelegate?
	
	open var shouldDisableInProgressCheck : Bool = false
	
	var fileListLoadedInternal = false {
		didSet {
			print("Did set")
		}
	}
	
	open var fileListLoaded : Bool {
		get {
			return fileListLoadedInternal
		}
	}
	
	var formatter = DateFormatter()
	
	var workingCache : [String : Any] = [:]
	
	var internalList : [StormcloudDocumentType : [StormcloudMetadata]] = [:] 

	var operationInProgress : Bool = true
	
	weak var restoreDelegate : StormcloudRestoreDelegate?
	
	var provider : DocumentProvider? {
		didSet {
			// External references to self will still be nil if the provider is set during initialisation
			provider?.delegate = self
			// If we've got a new provider, then we need to reset some state
			fileListLoadedInternal = false
			operationInProgress = true
		}
	}
	
	@objc public override init() {
		super.init()

		// If iCloud is enabled, start it up and get gathering
		if isUsingiCloud, let iCloudProvider = iCloudDocumentProvider() {
			provider = iCloudProvider
			UserDefaults.standard.set(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		} else {
			provider = LocalDocumentProvider()
			UserDefaults.standard.set(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		}
		
		// Needs to be set manually. See `provider` property
		provider?.delegate = self
		provider?.updateFiles()
		
		// Assume UTC for everything.
		self.formatter.timeZone = TimeZone(identifier: "UTC")
		
	}
	
	
	/// Returns a list of items for a given type. If the type does not yet exist, sets up the array
	///
	/// - Parameter type: A registered document type that you're interested in
	/// - Returns: An array of metadata objects that represent the files on disk or in iCloud
	open func items( for type: StormcloudDocumentType ) -> [StormcloudMetadata] {
		if let hasItems = internalList[type] {
			return hasItems
		} else {
			internalList[type] = []
		}
		return []
	}

	/**
	Enables iCloud
	
	- parameter move:       Pass true if you want the manager to attempt to copy any documents in iCloud to local storage
	- parameter completion: A completion handler to run when the attempt to copy documents has finished.
	*/
	open func enableiCloudShouldMoveDocuments( _ move : Bool, completion : ((_ error : StormcloudError?) -> Void)? ) {
		let currentItems = self.internalList
		deleteAllItems()

		if move {
			// Handle the moving of documents
			self.moveItemsToiCloud(currentItems, completion: completion)
		}
	}
	
	/**
	Disables iCloud in favour of local storage
	
	- parameter move:       Pass true if you want the manager to attempt to copy any documents in iCloud to local storage
	- parameter completion: A completion handler to run when the attempt to copy documents has finished.
	*/
	open func disableiCloudShouldMoveiCloudDocumentsToLocal( _ move : Bool, completion : ((_ moveSuccessful : Bool) -> Void)? ) {
		let currentItems = self.internalList
		deleteAllItems()

		if move {
			// Handle the moving of documents
			self.moveItemsFromiCloud(currentItems, completion: completion)
		}
	}
	
	func moveItemsToiCloud( _ items : [StormcloudDocumentType : [StormcloudMetadata]], completion : ((_ error : StormcloudError?) -> Void)? ) {
				
		// Our current provider should be an local Document Provider
		guard let currentProvider = provider as? LocalDocumentProvider else {
			completion?(.iCloudNotEnabled)
			return
		}
		
		guard let iCloudProvider = iCloudDocumentProvider() else {
			// Couldn't start up iCloud
			completion?(.iCloudUnavailable)
			return
		}
		provider = iCloudProvider
		
		guard let docsDir = currentProvider.documentsDirectory(), let iCloudDir = iCloudProvider.documentsDirectory() else {
			provider = LocalDocumentProvider()
			completion?(.iCloudUnavailable)
			return
		}
		
		UserDefaults.standard.set(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		
		var allItems = [StormcloudMetadata]()
		for type in StormcloudDocumentType.allTypes() {
			if let hasItems = items[type] {
				allItems.append(contentsOf: hasItems)
			}
		}
		
		DispatchQueue.global(qos: .default).async {
			var hasError : StormcloudError?
			for metadata in allItems {
				let finalURL = docsDir.appendingPathComponent(metadata.filename)
				let finaliCloudURL = iCloudDir.appendingPathComponent(metadata.filename)
				do {
					try FileManager.default.setUbiquitous(true, itemAt: finalURL, destinationURL: finaliCloudURL)
					self.stormcloudLog("Moved item from local \(finalURL) to iCloud: \(finaliCloudURL)")
				} catch {
					hasError = .couldntMoveDocumentToiCloud
					self.stormcloudLog("Error moving item: \(finalURL): \(error.localizedDescription)")
				}
			}
			
			DispatchQueue.main.async(execute: { () -> Void in
				completion?(hasError)
			})
		}
	}
	
	func moveItemsFromiCloud( _ items : [StormcloudDocumentType :  [StormcloudMetadata]], completion : ((_ success : Bool ) -> Void)? ) {
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
		provider = localProvider
		UserDefaults.standard.set(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
			
		var filenames = [String]()
		for (_,value) in items {
			let allNames = value.map() { $0.filename }
			filenames.append(contentsOf: allNames )
		}
		
		DispatchQueue.global(qos: .default).async {
			var success = true
			for element in filenames {
				let finalURL = docsDir.appendingPathComponent(element)
				let finaliCloudURL = iCloudDir.appendingPathComponent(element)
				do {
					try FileManager.default.setUbiquitous(false, itemAt: finaliCloudURL, destinationURL: finalURL)
					self.stormcloudLog("Moving files from iCloud: \(finaliCloudURL) to local URL: \(finalURL)")
				} catch {
					self.stormcloudLog("Error moving file: \(finaliCloudURL) from iCloud: \(error.localizedDescription)")
					success = false
				}
			}
			
			DispatchQueue.main.async(execute: { () -> Void in
//					self.prepareDocumentList()
				completion?(success)
			})
		}
	}
		
	deinit {
		print("deinit called")
		
		provider = nil
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
	
	func deleteAllItems() {
		for type in StormcloudDocumentType.allTypes() {
			if let hasItems = internalList[type] {
				let indexesToDelete = IndexSet(0..<hasItems.count)
				internalList[type]?.removeAll()
				self.delegate?.metadataListDidAddItemsAt(nil, andDeletedItemsAt: indexesToDelete, for: type)
			}
		}
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
		guard let baseURL = provider?.documentsDirectory() else {
			completion(.invalidURL, nil)
			return
		}
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
		
		let exists : [StormcloudMetadata]
		
		exists = items(for: documentType).filter({ (element) -> Bool in
			if element.filename == metadata.filename {
				return true
			}
			return false
		})

		if exists.count > 0 {
			completion(.backupFileExists, nil)
			return
		}
		
		assert(Thread.current == Thread.main)
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
			DispatchQueue.main.async(execute: { () -> Void in
				
				self.operationInProgress = false
				
				// If we were successful, and it hasn't been added in the meantime, then we can go ahead and append the metadata
				if !self.internalList[documentType]!.contains(metadata) {
					self.internalList[documentType]?.append(metadata)
					self.internalList[documentType]?.sort(by: { (data1, data2) -> Bool in
						return data1.date > data2.date
					})
					if let idx = self.internalList[documentType]?.index(of: metadata) {
						self.delegate?.metadataListDidAddItemsAt(IndexSet(integer: idx), andDeletedItemsAt: nil, for: documentType)
					}
				}
				completion(nil, (totalSuccess) ? metadata : metadata)
			})
		})
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
		
		
		guard let metadataList = internalList[metadata.type] else {
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
		
		guard let validItems = internalList[type] else {
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
	
	/**
	Deletes the document represented by the metadataItem object
	
	- parameter metadataItem: The Stormcloud Metadata object that represents the document
	- parameter completion:   The completion handler to run when the delete completes
	*/
	public func deleteItem(_ metadataItem : StormcloudMetadata, completion : @escaping (_ index : Int?, _ error : StormcloudError?) -> () ) {
		// Pull them out of the internal list first
		guard let itemURL = self.urlForItem(metadataItem), let idx = internalList[metadataItem.type]?.index(of: metadataItem) else {
			completion(nil, .couldntDelete)
			return
		}
		
		
		// Remove them from the internal list
		DispatchQueue.global(qos: .default).async {
			
			// TESTING ENVIRONMENT
			if StormcloudEnvironment.MangleDelete.isEnabled() {
				sleep(2)
				DispatchQueue.main.async(execute: { () -> Void in
					completion(nil, .couldntDelete )
				})
				return
			}
			// ENDs
			
			let coordinator = NSFileCoordinator(filePresenter: nil)
			coordinator.coordinate(writingItemAt: itemURL, options: .forDeleting, error:nil, byAccessor: { (url) -> Void in
				var hasError : NSError?
				do {
					try FileManager.default.removeItem(at: url)
				} catch let error as NSError  {
					hasError = error
				}
				if hasError != nil {
					completion(nil, .couldntDelete)
				} else {
					
					DispatchQueue.main.async {
						// If it's still in our internal list at this point, remove it and send the delegate message
						if let stillIdx = self.internalList[metadataItem.type]?.index(of: metadataItem) {
							self.internalList[metadataItem.type]!.remove(at: stillIdx)
							self.delegate?.metadataListDidAddItemsAt(nil, andDeletedItemsAt: IndexSet(integer: stillIdx), for: metadataItem.type)
						}
						completion(idx, nil)
					}
				}
			})

		}
	}
}


extension Stormcloud {
	func stormcloudLog( _ string : String ) {
		if StormcloudEnvironment.VerboseLogging.isEnabled() {
			print(string)
		}
	}
}



