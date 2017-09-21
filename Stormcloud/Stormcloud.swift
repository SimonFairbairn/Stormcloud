//
//  Stormcloud.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit
import CoreData

// A simple protocol with an implementation in an extension that will help us manage the environment
public protocol StormcloudEnvironmentVariable  {
	func stringValue() -> String
}

public extension StormcloudEnvironmentVariable {
	func isEnabled() -> Bool {
		let env = ProcessInfo.processInfo.environment
		if let _ = env[self.stringValue()]  {
			return true
		} else {
			return false
		}
	}
}

public protocol StormcloudRestoreDelegate {
	func stormcloud( stormcloud : Stormcloud, shouldRestore objects: [String : AnyObject], toEntityWithName name: String ) -> Bool
}

/**
A list of environment variables that you can use for debugging purposes.

Usage:

1. `Product -> Scheme -> Edit Scheme...`
2. Under `Environment variables` tap the `+` icon
3. Add `Stormcloud` + the enum case (e.g. `StormcloudMangleDelete`) as the name field. No value is required.

Valid variables:

- **`StormcloudMangleDelete`** : Mangles a delete so you can test your apps response to errors correctly
- **`StormcloudVerboseLogging`** : More verbose output to see what's happening within Stormcloud
*/
enum StormcloudEnvironment : String, StormcloudEnvironmentVariable {
	case MangleDelete = "StormcloudMangleDelete"
	case VerboseLogging = "StormcloudVerboseLogging"
	func stringValue() -> String {
		return self.rawValue
	}
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
@objc
public protocol StormcloudDelegate {
	func metadataListDidChange(_ manager : Stormcloud)
	func metadataListDidAddItemsAtIndexes( _ addedItems : IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?)
}

open class Stormcloud: NSObject {
	
	/// The file extension to use for the backup files
	open var fileExtension = "json"
	
	/// Whether or not the backup manager is currently using iCloud (read only)
	open var isUsingiCloud : Bool {
		get {
			return UserDefaults.standard.bool(forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		}
	}
	
	/// A list of currently available backup metadata objects.
	open var metadataList : [StormcloudMetadata] {
		get {
			return self.backingMetadataList
		}
	}
	
	/// The backup manager delegate
	open var delegate : StormcloudDelegate?
	
	/// The number of files to keep before older ones are deleted. 0 = never delete.
	open var fileLimit : Int = 0
	
	var formatter = DateFormatter()
	
	var iCloudURL : URL?
	var metadataQuery : NSMetadataQuery = NSMetadataQuery()
	
	var backingMetadataList : [StormcloudMetadata] = []
	var internalMetadataList : [StormcloudMetadata] = []
	var internalQueryList : [String : StormcloudMetadata] = [:]
	var pauseMetadata : Bool = false
	
	var moveDocsToiCloud : Bool = false
	var moveDocsToiCloudCompletion : ((_ error : StormcloudError?) -> Void)?
	
	var operationInProgress : Bool = false
	
	var workingCache : [String : Any] = [:]
	
	var restoreDelegate : StormcloudRestoreDelegate?
	
	public override init() {
		super.init()
		if self.isUsingiCloud {
			_ = self.enableiCloudShouldMoveLocalDocumentsToiCloud(false, completion: nil)
		}
		// Assume UTC for everything.
		self.formatter.timeZone = TimeZone(identifier: "UTC")
		self.prepareDocumentList()
	}
	
	/**
	Reloads the current metadata list, either from iCloud or from local documents. If you are switching between storage locations, using the appropriate methods will automatically reload the list of documents so there's no need to call this.
	*/
	open func reloadData() {
		self.prepareDocumentList()
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
			if let hasCompletion = completion {
				hasCompletion(StormcloudError.iCloudUnavailable)
			}
			
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
			self.moveItemsFromiCloud(self.backingMetadataList, completion: completion)
		}
		
		UserDefaults.standard.removeObject(forKey: StormcloudPrefKey.iCloudToken.rawValue)
		UserDefaults.standard.set(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
		
		
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
	
	func moveItemsFromiCloud( _ items : [StormcloudMetadata], completion : ((_ success : Bool ) -> Void)? ) {
		// Copy all of the local documents to iCloud
		if let docsDir = self.documentsDirectory(), let iCloudDir = iCloudDocumentsDirectory() {
			
			let filenames = items.map { $0.filename }
			
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
					self.prepareDocumentList()
					completion?(success)
				})
			}
		} else {
			completion?(false)
		}
	}
	
	
	func iCloudUserChanged( _ notification : Notification ) {
		// Handle user changing
		
		self.prepareDocumentList()
		
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
		if self.isUsingiCloud {
			return self.iCloudDocumentsDirectory()?.appendingPathComponent(item.filename)
		} else {
			return self.documentsDirectory()?.appendingPathComponent(item.filename)
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
		
		if self.operationInProgress {
			completion(.backupInProgress, nil)
			return
		}
		self.operationInProgress = true
		
		if let url = self.urlForItem(metadata) {
			let document = BackupDocument(fileURL : url)
			let _ = document.documentState
			document.open(completionHandler: { (success) -> Void in
				
				if !success {
					self.operationInProgress = false
					completion(.couldntOpenDocument, nil)
					return
				}
				
				DispatchQueue.main.async(execute: { () -> Void in
					self.operationInProgress = false
					completion(nil, document.objectsToBackup)
				})
			})
		} else {
			self.operationInProgress = false
			completion(.invalidURL, nil)
		}
	}
	

	
	public func deleteItemsOverLimit( _ completion : @escaping ( _ error : StormcloudError? ) -> () ) {
		
		// Knock one off as we're about to back up
		let limit = self.fileLimit - 1
		var itemsToDelete : [StormcloudMetadata] = []
		if self.fileLimit > 0 && self.metadataList.count > limit {
			
			
			for i in self.fileLimit..<self.metadataList.count {
				let metadata = self.metadataList[i]
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
		var urlList : [ URL : Int ] = [:]
		var errorList : [StormcloudMetadata] = []
		for item in metadataItems {
			if let itemURL = self.urlForItem(item), let idx = self.internalMetadataList.index(of: item) {
				urlList[itemURL] = idx
			} else {
				errorList.append(item)
			}
		}
		
		for (_, idx) in urlList {
			self.internalMetadataList.remove(at: idx)
		}
		self.sortDocuments()
		
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
		
		
		//
		//        if let itemURL = self.urlForItem(metadataItem), let idx = self.internalMetadataList.indexOf(metadataItem) {
		//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
		//
		//                // TESTING ENVIRONMENT
		//                if StormcloudEnvironment.MangleDelete.isEnabled() {
		//                    sleep(2)
		//                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
		//                        let deleteError = StormcloudError.CouldntDelete
		//                        let error = NSError(domain:deleteError.domain(), code: deleteError.rawValue, userInfo: nil)
		//                        completion(index: nil, error: error )
		//                    })
		//                    return
		//                }
		//                // ENDs
		//
		//                let coordinator = NSFileCoordinator(filePresenter: nil)
		//                coordinator.coordinateWritingItemAtURL(itemURL, options: .ForDeleting, error:nil, byAccessor: { (url) -> Void in
		//                    var hasError : NSError?
		//                    do {
		//                        try NSFileManager.defaultManager().removeItemAtURL(url)
		//                    } catch let error as NSError  {
		//                        hasError = error
		//                    }
		//                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
		//                        self.internalMetadataList.removeAtIndex(idx)
		//                        completion(index : (hasError != nil) ? idx : nil, error: hasError)
		//                        self.sortDocuments()
		//                    })
		//                })
		//            })
		//        } else {
		//
		//
		//        }
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


// MARK: - Prepare Documents

extension Stormcloud {
	
	
	func prepareDocumentList() {
		
		self.internalQueryList.removeAll()
		self.internalMetadataList.removeAll()
		self.sortDocuments()
		if self.isUsingiCloud  {
			
			var myContainer : URL?
			DispatchQueue.global(qos: .default).async {
				
				myContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
				self.iCloudURL = myContainer
				
				var stormcloudError : StormcloudError?
				if self.moveDocsToiCloud {
					if let iCloudDir = self.iCloudDocumentsDirectory() {
						for fileURL in self.listLocalDocuments() {
							if fileURL.pathExtension == self.fileExtension {
								
								let finaliCloudURL = iCloudDir.appendingPathComponent(fileURL.lastPathComponent)
								print( finaliCloudURL)
								do {
									try FileManager.default.setUbiquitous(true, itemAt: fileURL, destinationURL: finaliCloudURL)
								} catch {
									stormcloudError = StormcloudError.couldntMoveDocumentToiCloud
								}
								
							}
						}
					}
					self.moveDocsToiCloud = false
				}
				
				DispatchQueue.main.async(execute: { () -> Void in
					
					// Start metadata search
					self.loadiCloudDocuments()
					// Set URL
					
					// If we have a completion handler from earlier
					if let completion = self.moveDocsToiCloudCompletion {
						completion(stormcloudError)
						self.moveDocsToiCloudCompletion = nil;
					}
					
				})
			}
		} else {
			self.loadLocalDocuments()
		}
	}
	
	func sortDocuments() {
		
		
		//        dispatch_async(dispatch_get_main_queue(), { () -> Void in
		self.internalMetadataList.sort { (element1, element2) -> Bool in
			if (element2.date as NSDate).earlierDate(element1.date as Date) == element2.date as Date {
				return true
			}
			return false
		}
		
		// Has anything been removed? Filter out anything from the documents that isn't in the manager
		let removeItems = self.backingMetadataList.filter { (element) -> Bool in
			if self.internalMetadataList.contains(element) {
				return false
			}
			return true
		}
		
		let indexesToDelete = NSMutableIndexSet()
		
		for item in removeItems {
			if let idx = self.backingMetadataList.index(of: item) {
				indexesToDelete.add(idx)
			}
		}
		
		
		let sortedIndexes = indexesToDelete.sorted { (index1, index2) -> Bool in
			return index1 > index2
		}
		for idx in sortedIndexes {
			self.backingMetadataList.remove(at: idx)
		}
		
		
		// Has anything been added?
		let indexesToAdd = NSMutableIndexSet()
		let addedItems = self.internalMetadataList.filter { (element) -> Bool in
			if self.backingMetadataList.contains(element ) {
				return false
			}
			return true
		}
		for item in addedItems {
			if let idx = self.internalMetadataList.index(of: item) {
				indexesToAdd.add(idx)
				let item = self.internalMetadataList[idx]
				self.backingMetadataList.insert(item, at: idx)
			}
		}
		self.delegate?.metadataListDidAddItemsAtIndexes((indexesToAdd.count > 0 ) ? indexesToAdd as IndexSet : nil, andDeletedItemsAtIndexes: (indexesToDelete.count > 0) ? indexesToDelete as IndexSet : nil)
		
		//        })
	}
	
	
}

// MARK: - Local Document Handling

extension Stormcloud {
	
	func listLocalDocuments() -> [URL] {
		let docs : [URL]
		if let url = self.documentsDirectory()  {
			
			do {
				docs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
			} catch {
				stormcloudLog("Error listing contents of \(url)")
				
				docs = []
			}
		} else {
			docs = []
		}
		return docs
	}
	
	func loadLocalDocuments() {
		for fileURL in self.listLocalDocuments() {
			if fileURL.pathExtension == self.fileExtension {
				let backup = StormcloudMetadata(fileURL: fileURL)
				self.internalMetadataList.append(backup)
				self.sortDocuments()
			}
		}
	}
	
	
	func documentsDirectory() -> URL? {
		if let docsURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first {
			return docsURL
		}
		return nil
	}
}

// MARK: - iCloud Document Handling

extension Stormcloud {
	
	func loadiCloudDocuments() {
		
		if self.metadataQuery.isStopped {
			stormcloudLog("Metadata query stopped")
			self.metadataQuery.start()
			return
		}
		
		if self.metadataQuery.isGathering {
			stormcloudLog("Metadata query gathering")
			return
		}
		
		stormcloudLog("Beginning metadata query with file extension \(self.fileExtension)")
		
		self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
		self.metadataQuery.predicate = NSPredicate(format: "%K CONTAINS '\(self.fileExtension)'", NSMetadataItemPathKey)
		
		NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.metadataFinishedGathering), name:NSNotification.Name.NSMetadataQueryDidFinishGathering , object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.metadataUpdated), name:NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
		
		self.metadataQuery.start()
	}
	
	func iCloudDocumentsDirectory() -> URL? {
		if self.isUsingiCloud {
			if let hasiCloudDir = self.iCloudURL {
				return hasiCloudDir.appendingPathComponent("Documents")
			}
		}
		return nil
	}
	
	func metadataFinishedGathering() {
		
		stormcloudLog("Metadata finished gathering")
		
		//        self.metadataQuery.stopQuery()
		self.metadataUpdated()
	}
	
	func metadataUpdated() {
		
		stormcloudLog("Metadata updated")
		
		if let items = self.metadataQuery.results as? [NSMetadataItem] {
			
			stormcloudLog("Metadata query found \(items.count) items")
			
			for item in items {
				if let fname = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String {
					
					if let hasBackup = self.internalQueryList[fname] {
						hasBackup.iCloudMetadata = item
					} else {
						if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
							let backup = StormcloudMetadata(fileURL: url)
							backup.iCloudMetadata = item
							self.internalMetadataList.append(backup)
							self.internalQueryList[fname] = backup
						}
					}
				}
			}
		}
		self.sortDocuments()
	}
}

extension Stormcloud {
	func stormcloudLog( _ string : String ) {
		if StormcloudEnvironment.VerboseLogging.isEnabled() {
			print(string)
		}
	}
	
}



