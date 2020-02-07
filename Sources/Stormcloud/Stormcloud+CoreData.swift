//
//  Stormcloud+CoreData.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 20/10/2016.
//  Copyright © 2016 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

public enum StormcloudCoreDataStatus {
	case deletingOldObjects, insertingNewObjects, establishingRelationships
}

public protocol StormcloudCoreDataDelegate : StormcloudDelegate {
	func stormcloud( _ stormcloud : Stormcloud, coreDataHit error : StormcloudError, for status : StormcloudCoreDataStatus)
	func stormcloud( _ stormcloud : Stormcloud, didUpdate objectsUpdated : Int, of total : Int, for status : StormcloudCoreDataStatus )
}


// MARK: - Restore Core Data

extension Stormcloud {
	
	func insertIndividualObjectsWithContext( _ context : NSManagedObjectContext, data : [String : AnyObject], completion : @escaping (_ success : Bool) -> ()  ) {
		
		stormcloudLog("\(#function)")
		
		let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		privateContext.parent = context
		privateContext.perform { () -> Void in
			
			self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
			
			var success = true
			
			var allObjects : [NSManagedObject] = []
			
			for (key, value) in data {
				
				
				if var dict = value as? [ String : AnyObject], let entityName = dict[StormcloudEntityKeys.EntityType.rawValue] as? String {
					self.stormcloudLog("\tCreating entity \(entityName)")
					
					if let delegate = self.restoreDelegate, delegate.stormcloud(stormcloud: self, shouldRestore: dict, toEntityWithName: entityName) {
						
						// At this point it will have a temporary ID
						let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: privateContext)
						
						dict[StormcloudEntityKeys.ManagedObject.rawValue] = object
						
						self.workingCache[key] = dict
						
						allObjects.append(object)
						
						for (propertyName, propertyValue ) in dict {
							for propertyDescription in object.entity.properties {
								if let attribute = propertyDescription as? NSAttributeDescription , propertyName == propertyDescription.name {
									
									self.stormcloudLog("\t\tFound attribute: \(propertyName)")
									
									self.setAttribute(attribute, onObject: object, withData: propertyValue)
								}
							}
						}
						for relationshipDescription in object.entity.relationshipsByName {
							if let hasRelationship = dict[relationshipDescription.key] as? [[String : AnyObject]] {
								var relatedObjects = [NSManagedObject]()
								if let entityDescription = relationshipDescription.value.destinationEntity, let name = entityDescription.name {
									for relatedJSON in hasRelationship {

										if ( relatedJSON.isEmpty ) {
											continue
										}
										
										let relatedObject = NSEntityDescription.insertNewObject(forEntityName: name, into: privateContext)
										
										for (propertyName, propertyValue ) in relatedJSON {
											for propertyDescription in relatedObject.entity.properties {
												if let attribute = propertyDescription as? NSAttributeDescription , propertyName == propertyDescription.name {
													
													self.stormcloudLog("\t\tFound attribute: \(propertyName)")
													
													self.setAttribute(attribute, onObject: relatedObject, withData: propertyValue)
												}
											}
										}
										relatedObjects.append(relatedObject)
									}
									
									
								}
								
								if relationshipDescription.value.isToMany && relatedObjects.count > 0 {
									self.stormcloudLog("\tRestoring To-many relationship \(String(describing: object.entity.name)) ->> \(relationshipDescription.value.name) with \(relatedObjects.count) objects")
									if relationshipDescription.value.isOrdered {
										
										let set = NSOrderedSet(array: relatedObjects)
										object.setValue(set, forKey: relationshipDescription.value.name)
										
									} else {
										let set = NSSet(array: relatedObjects)
										object.setValue(set, forKey: relationshipDescription.value.name)
									}
								}
							}
						}
					}
				}
			}
			
			
			self.stormcloudLog("\tAttempting to obtain permanent IDs...")
			do {
				try privateContext.obtainPermanentIDs(for: allObjects)
				self.stormcloudLog("\t\tSuccess")
			} catch {
				success = false
				self.stormcloudLog("\t\tCouldn't obtain permanent IDs")
			}
			
			if StormcloudEnvironment.VerboseLogging.isEnabled() {
				
				for object in allObjects {
					self.stormcloudLog("\t\tIs Temporary ID: \(object.objectID.isTemporaryID)")
					self.stormcloudLog("\t\t\tNew ID: \(object.objectID)")
				}
				
			}
			
			do {
				try privateContext.save()
			} catch {
				// TODO : Better error handling
				success = false
				self.stormcloudLog("Error saving during restore")
			}
			
			context.performAndWait({ () -> Void in
				do {
					try context.save()
				} catch {
					// TODO : Better error handling
					success = false
					self.stormcloudLog("Error saving parent context")
				}
				if let parentContext = context.parent {
					do {
						try parentContext.save()
					} catch {
						// TODO : Better error handling
						success = false
						self.stormcloudLog("Error saving top level")
					}
				}
				
			})
						
			DispatchQueue.main.async { () -> Void in
				completion(success)
			}
		}
	}
	
	
	func insertObjectsWithContext( _ context : NSManagedObjectContext, data : [String : AnyObject], completion : @escaping (_ success : Bool) -> ()  ) {
		
		stormcloudLog("\(#function)")
		
		let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		privateContext.parent = context
		privateContext.perform { [unowned self] () -> Void in
			
			self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
			
			var success = true
			
			// First we get all the objects
			// Then we delete them all!
			if let entities = privateContext.persistentStoreCoordinator?.managedObjectModel.entities {
				
				self.stormcloudLog("Found \(entities.count) entities:")
				
				var objectsToDelete = [NSManagedObject]()
				for entity in entities {
					if let entityName = entity.name {
						
						self.stormcloudLog("\t\(entityName)")
						let currentEntities : [NSManagedObject]
						let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
						
						do {
							currentEntities = try privateContext.fetch(request) as! [NSManagedObject]
						} catch {
							DispatchQueue.main.async {
								self.coreDataDelegate?.stormcloud( self, coreDataHit : .entityDeleteFailed, for: .deletingOldObjects)
								sleep(1)
							}
							
							currentEntities = []
						}
						objectsToDelete.append(contentsOf: currentEntities)
					}
				}
				
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: 0, of: objectsToDelete.count, for: .deletingOldObjects )
				}

				var count = 0
				for object in objectsToDelete {
					privateContext.delete(object)
					count += 1
					if count % 40 == 0 {
						DispatchQueue.main.async {
							self.coreDataDelegate?.stormcloud( self, didUpdate: count, of: objectsToDelete.count, for: .deletingOldObjects )
						}
					}
				}
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: objectsToDelete.count, of: objectsToDelete.count, for: .deletingOldObjects )
				}
				
				// Push the changes to the store
				do {
					try privateContext.save()
				} catch {
					success = false
					self.stormcloudLog("Error saving context")
					abort()
				}
				
				context.performAndWait({ () -> Void in
					do {
						try context.save()
					} catch {
						success = false
						self.stormcloudLog("Error saving parent context")
						abort()
					}
					
					if let parentContext = context.parent {
						do {
							try parentContext.save()
						} catch {
							// TODO : Better error handling
							self.stormcloudLog("Error saving top level")
						}
					}
				})
				
				var allObjects : [NSManagedObject] = []
				
				var insertCount = 0
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: insertCount, of: data.count, for: .insertingNewObjects )
				}
				for (key, value) in data {
					insertCount += 1
					if var dict = value as? [ String : AnyObject], let entityName = dict[StormcloudEntityKeys.EntityType.rawValue] as? String {
						self.stormcloudLog("\tCreating entity \(entityName)")
						
						// At this point it will have a temporary ID
						let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: privateContext)
						
						dict[StormcloudEntityKeys.ManagedObject.rawValue] = object
						
						self.workingCache[key] = dict
						
						allObjects.append(object)
						
						for (propertyName, propertyValue ) in dict {
							for propertyDescription in object.entity.properties {
								if let attribute = propertyDescription as? NSAttributeDescription , propertyName == propertyDescription.name {
									self.stormcloudLog("\t\tFound attribute: \(propertyName)")
									self.setAttribute(attribute, onObject: object, withData: propertyValue)
								}
							}
						}
						DispatchQueue.main.async {
							self.coreDataDelegate?.stormcloud( self, didUpdate: insertCount, of: data.count, for: .insertingNewObjects )
						}
					}
				}
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: data.count, of: data.count, for: .insertingNewObjects )
				}
				
				self.stormcloudLog("\tAttempting to obtain permanent IDs...")
				do {
					try privateContext.obtainPermanentIDs(for: allObjects)
					self.stormcloudLog("\t\tSuccess")
				} catch {
					self.stormcloudLog("\t\tCouldn't obtain permanent IDs")
				}
				
				if StormcloudEnvironment.VerboseLogging.isEnabled() {
					
					for object in allObjects {
						self.stormcloudLog("\t\tIs Temporary ID: \(object.objectID.isTemporaryID)")
						self.stormcloudLog("\t\t\tNew ID: \(object.objectID)")
					}
					
				}
				
				do {
					try privateContext.save()
				} catch {
					// TODO : Better error handling
					self.stormcloudLog("Error saving during restore")
				}
				
				context.performAndWait({ () -> Void in
					do {
						try context.save()
					} catch {
						// TODO : Better error handling
						self.stormcloudLog("Error saving parent context")
					}
					if let parentContext = context.parent {
						do {
							try parentContext.save()
						} catch {
							// TODO : Better error handling
							self.stormcloudLog("Error saving top level")
						}
					}
					
				})
				
				
				// An array of managed objects, whose object IDs are now no good.
				// A dictionary of the data, with one of the keys pointing to a managed object
				
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: 0, of: self.workingCache.count, for: .establishingRelationships )
				}
				count = 0
				for (_, value) in self.workingCache {
					count += 1
					if let dict = value as? [String : AnyObject], let object = dict[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
						for propertyDescription in object.entity.properties {
							if let relationship = propertyDescription as? NSRelationshipDescription {
								self.setRelationship(relationship, onObject: object, withData : dict, inContext: privateContext)
								DispatchQueue.main.async {
									self.coreDataDelegate?.stormcloud( self, didUpdate: count, of: self.workingCache.count, for: .establishingRelationships )
								}
							}
						}
					}
				}
				DispatchQueue.main.async {
					self.coreDataDelegate?.stormcloud( self, didUpdate: self.workingCache.count, of: self.workingCache.count, for: .establishingRelationships )
				}
				
				do {
					try privateContext.save()
				} catch {
					abort()
				}
				
				DispatchQueue.main.async { () -> Void in
					completion(success)
				}
				
			}
		}
	}
	
	func setRelationship( _ relationship : NSRelationshipDescription, onObject : NSManagedObject, withData data: [ String : AnyObject], inContext : NSManagedObjectContext ) {
		
		
		
		if let _ =  inContext.registeredObject(for: onObject.objectID) {
			
		} else {
			return;
		}
		
		if let relationshipIDs = data[relationship.name] as? [String] {
			var setObjects : [NSManagedObject] = []
			for id in relationshipIDs {
				
				
				
				if let cacheData = self.workingCache[id] as? [String : AnyObject], let relatedObject = cacheData[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
					if !relationship.isToMany {
						self.stormcloudLog("\tRestoring To-one relationship \(String(describing: onObject.entity.name)) -> \(relationship.name)")
						onObject.setValue(relatedObject, forKey: relationship.name)
					} else {
						setObjects.append(relatedObject)
					}
					
				}

			}
			
			
			if relationship.isToMany && setObjects.count > 0 {
				self.stormcloudLog("\tRestoring To-many relationship \(String(describing: onObject.entity.name)) ->> \(relationship.name) with \(setObjects.count) objects")
				if relationship.isOrdered {
					
					let set = NSOrderedSet(array: setObjects)
					onObject.setValue(set, forKey: relationship.name)
					
				} else {
					let set = NSSet(array: setObjects)
					onObject.setValue(set, forKey: relationship.name)
				}
			}
		}
	}
	
	
	func getAttribute( _ attribute : NSAttributeDescription, fromObject object : NSManagedObject ) -> Any? {
		
		switch attribute.attributeType {
		case .integer16AttributeType, .integer32AttributeType,.integer64AttributeType, .doubleAttributeType, .floatAttributeType, .stringAttributeType, .booleanAttributeType :
			
			return object.value(forKey: attribute.name)
			
			
		case .decimalAttributeType:
			
			if let decimal = object.value(forKey: attribute.name) as? NSDecimalNumber {
				return decimal.stringValue
			}
		case .dateAttributeType:
			if let date = object.value(forKey: attribute.name) as? Date {
				return formatter.string(from: date)
			}
		case .binaryDataAttributeType, .transformableAttributeType:
			if let value = object.value(forKey: attribute.name) as? NSCoding {
				let mutableData = NSMutableData()
				let archiver = NSKeyedArchiver(forWritingWith: mutableData)
				archiver.encode(value, forKey: attribute.name)
				archiver.finishEncoding()
				return mutableData.base64EncodedString(options: NSData.Base64EncodingOptions())
			}
		case .objectIDAttributeType, .undefinedAttributeType, .UUIDAttributeType, .URIAttributeType:
			break
			
		@unknown default:
			preconditionFailure("Unknown switch case for attribute type in \(#file)")
		}
		
		
		return nil
	}
	
	
	func setAttribute( _ attribute : NSAttributeDescription, onObject object : NSManagedObject,  withData data : AnyObject? ) {
		switch attribute.attributeType {
		case .integer16AttributeType, .integer32AttributeType,.integer64AttributeType, .doubleAttributeType, .floatAttributeType:
			if let val = data as? NSNumber {
				object.setValue(val, forKey: attribute.name)
			} else {
				stormcloudLog("Setting Number : \(String(describing: data)) not Number")
			}
			
		case .decimalAttributeType:
			if let val = data as? String {
				let decimal = NSDecimalNumber(string: val)
				object.setValue(decimal, forKey: attribute.name)
			} else {
				stormcloudLog("Setting Decimal : \(String(describing: data)) not String")
			}
			
		case .stringAttributeType:
			if let val = data as? String {
				object.setValue(val, forKey: attribute.name)
			} else {
				stormcloudLog("Setting String : \(String(describing: data)) not String")
			}
		case .booleanAttributeType:
			if let val = data as? NSNumber {
				object.setValue(val.boolValue, forKey: attribute.name)
			} else {
				stormcloudLog("Setting Bool : \(String(describing: data)) not Number")
			}
		case .dateAttributeType:
			if let val = data as? String, let date = self.formatter.date(from: val) {
				object.setValue(date, forKey: attribute.name)
			}
		case .binaryDataAttributeType, .transformableAttributeType:
			if let val = data as? String {
				let data = Data(base64Encoded: val, options: NSData.Base64DecodingOptions())
				let unarchiver = NSKeyedUnarchiver(forReadingWith: data!)
				if let data = unarchiver.decodeObject(forKey: attribute.name) as? NSObject {
					object.setValue(data, forKey: attribute.name)
				}
				unarchiver.finishDecoding()
			} else {
				stormcloudLog("Transformable/Binary type : \(String(describing: data)) not String")
			}
		case .objectIDAttributeType, .undefinedAttributeType, .UUIDAttributeType, .URIAttributeType:
			break
		@unknown default:
			preconditionFailure("Unknown switch case for attribute type in \(#file)")
		}
	}

	/**
	Restores a backup to Core Data from a UIManagedDocument
	
	- parameter document:   The backup document to restore
	- parameter context:    The context to restore the objects to
	- parameter completion: A completion handler
	*/
	public func restoreCoreDataBackup(from document : JSONDocument, to context : NSManagedObjectContext,  completion : @escaping (_ error : StormcloudError?) -> () ) {
		
		defer {
			document.close(completionHandler: nil)
		}
		
		guard let data = document.objectsToBackup as? [String : AnyObject] else {
			self.operationInProgress = false
			completion(.couldntRestoreJSON)
			return
		}		
		self.insertObjectsWithContext(context, data: data) { (success)  -> Void in
			self.operationInProgress = false
			let error : StormcloudError?  = (success) ? nil : StormcloudError.couldntRestoreJSON
			completion(error)
		}
	}
	
	/**
	Restores a backup to Core Data from a StormcloudMetadata object
	
	- parameter metadata:  The metadata that represents the document
	- parameter context:    The context to restore the objects to
	- parameter completion: A completion handler
	*/
	
	public func restoreCoreDataBackup(from metadata : StormcloudMetadata, to context : NSManagedObjectContext,  completion : @escaping (_ error : StormcloudError?) -> () ) {

		
		guard self.operationInProgress == false else {
			completion(.backupInProgress)
			return
		}
		guard let url = self.urlForItem(metadata) else {
			completion(.invalidURL)
			return
		}
		do {
			try context.save()
		} catch {
			stormcloudLog("Error saving context")
			completion(.couldntSaveManagedObjectContext)
			return
		}

		self.operationInProgress = true
		
		let document = JSONDocument(fileURL : url)
		document.open(completionHandler: { [unowned self] (success) -> Void in
			
			if !success {
				self.operationInProgress = false
				completion(.couldntOpenDocument)
				return
			}
			
			DispatchQueue.main.async(execute: { [unowned self] () -> Void in
				self.restoreCoreDataBackup(from: document, to: context, completion: completion)
			})
		})
	}
}


// MARK: - Backup

extension Stormcloud {
	
	
	/// Backup an arbitrary collection of Core Data entities and convert them into JSON. Resolves relationships into their components.
	///
	/// - parameter objects:    An array of managed objects to backup
	/// - parameter completion: A completion handler to be called when the process is complete
	func backupCoreDataObjects( objects : [NSManagedObject], completion : @escaping ( _ error : StormcloudError?, _ metadata : StormcloudMetadata?) -> () ) {
		
		guard let context = objects.first?.managedObjectContext else {
			return
		}
		
		var temporaryObjectIDs : [NSManagedObject] = objects.filter() { $0.objectID.isTemporaryID }
		do {
			try context.obtainPermanentIDs(for: temporaryObjectIDs)
		} catch {
			print("Error fetching permanent IDs")
		}
		
		temporaryObjectIDs = objects.filter() { $0.objectID.isTemporaryID }
		if temporaryObjectIDs.count > 0 {
			print("Error converting temporary IDs")
		}
		
		let objectIDs : [NSManagedObjectID] = objects.map() { $0.objectID }
		
		let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		privateContext.parent = context
		privateContext.perform { () -> Void in
			
			var managedObjects : [NSManagedObject] = []
			for objectID in objectIDs {
				managedObjects.append(privateContext.object(with: objectID))
			}
			
			// Dictionaries are a list of all objects, with their ManagedObjectID as the key and a dictionary of their parts as the object
			var dictionary : [String : [ String : Any ] ] = [:]
			
			self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
			for object in managedObjects {
				let uriRepresentation = object.objectID.uriRepresentation().absoluteString
				
				var internalDictionary : [String : Any] = [StormcloudEntityKeys.EntityType.rawValue : object.entity.name! as AnyObject]
				
				for propertyDescription in object.entity.properties {
					if let attribute = propertyDescription as? NSAttributeDescription {
						internalDictionary[attribute.name] = self.getAttribute(attribute, fromObject: object)
					}
					
					if let relationship = propertyDescription as? NSRelationshipDescription {
						
						var relationshipArray : [[String : Any]] = [[:]]
						
						var objectIDs : [String] = []
						if let objectSet =  object.value(forKey: relationship.name) as? NSSet, let objectArray = objectSet.allObjects as? [NSManagedObject] {
							for object in objectArray {
								var objectDictionary : [String : Any] = [:]
								objectIDs.append(object.objectID.uriRepresentation().absoluteString)
								for propertyDescription in object.entity.properties {
									if let attribute = propertyDescription as? NSAttributeDescription {
										objectDictionary[attribute.name] = self.getAttribute(attribute, fromObject: object)
									}
								}
								relationshipArray.append(objectDictionary)
							}
						}
						
						if let relationshipObject = object.value(forKey: relationship.name) as? NSManagedObject {
							let objectID = relationshipObject.objectID.uriRepresentation().absoluteString
							objectIDs.append(objectID)
							
						}
						internalDictionary[relationship.name] = relationshipArray
						
					}
				}
				dictionary[uriRepresentation] = internalDictionary
				
			}
			
			
			
			if !JSONSerialization.isValidJSONObject(dictionary) {
				
				self.stormcloudLog("\(#function) Error: Dictionary not valid: \(dictionary)")
				
				DispatchQueue.main.async(execute: { () -> Void in
					self.operationInProgress = false
					completion(.invalidJSON, nil)
				})
			} else {
				DispatchQueue.main.async(execute: { () -> Void in
					self.operationInProgress = false
					
					self.addDocument(withData: dictionary, for: .json, completion: completion)
					
//					self.backupObjectsToJSON(dictionary as AnyObject, completion: completion)
				})
			}
		}
		
		
		
	}
	
	public func backupCoreDataEntities( in currentContext : NSManagedObjectContext, completion : @escaping ( _ error : StormcloudError?, _ metadata : StormcloudMetadata?) -> () ) {
		
		self.stormcloudLog("Beginning backup of Core Data with context : \(currentContext)")
		
		do {
			try currentContext.save()
		} catch {
			stormcloudLog("Error saving context")
		}
		if self.operationInProgress {
			completion(.backupInProgress, nil)
			return
		}
		self.operationInProgress = true
		
		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.parent = currentContext
		context.perform { () -> Void in
			
			// Dictionaries are a list of all objects, with their ManagedObjectID as the key and a dictionary of their parts as the object
			var dictionary : [String : [ String : Any ] ] = [:]
			
			if let entities = context.persistentStoreCoordinator?.managedObjectModel.entities {
				
				self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
				for entity in entities {
					if let entityName = entity.name {
						let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
						
						let allObjects : [NSManagedObject]
						do {
							allObjects = try context.fetch(request) as! [NSManagedObject]
						} catch {
							allObjects = []
						}
						
						self.stormcloudLog("Found \(allObjects.count) of \(entityName) to back up")
						
						for object in allObjects {
							let uriRepresentation = object.objectID.uriRepresentation().absoluteString
							
							var internalDictionary : [String : Any] = [StormcloudEntityKeys.EntityType.rawValue : entityName as AnyObject]
							
							for propertyDescription in entity.properties {
								if let attribute = propertyDescription as? NSAttributeDescription {
									internalDictionary[attribute.name] = self.getAttribute(attribute, fromObject: object)
								}
								
								if let relationship = propertyDescription as? NSRelationshipDescription {
									var objectIDs : [String] = []
									if let objectSet =  object.value(forKey: relationship.name) as? NSSet, let objectArray = objectSet.allObjects as? [NSManagedObject] {
										for object in objectArray {
											
											objectIDs.append(object.objectID.uriRepresentation().absoluteString)
										}
									}
									
									if let relationshipObject = object.value(forKey: relationship.name) as? NSManagedObject {
										let objectID = relationshipObject.objectID.uriRepresentation().absoluteString
										objectIDs.append(objectID)
										
									}
									internalDictionary[relationship.name] = objectIDs
								}
							}
							dictionary[uriRepresentation] = internalDictionary
							
						}
					}
				}
				if !JSONSerialization.isValidJSONObject(dictionary) {
					
					self.stormcloudLog("\(#function) Error: Dictionary not valid: \(dictionary)")
					
					DispatchQueue.main.async(execute: { () -> Void in
						self.operationInProgress = false
						completion(.invalidJSON, nil)
					})
				} else {
					DispatchQueue.main.async(execute: { () -> Void in
						self.operationInProgress = false
						self.addDocument(withData: dictionary, for: .json, completion: completion)
//						self.backupObjectsToJSON(dictionary as AnyObject, completion: completion)
					})
				}
			}
		}
	}
	
}

