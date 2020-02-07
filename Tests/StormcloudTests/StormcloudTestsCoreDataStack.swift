//
//  StormcloudTestsCoreDataStack.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import CoreData
import Stormcloud


public enum CoreDataStackEnvironmentVariables : String, StormcloudEnvironmentVariable {
    case UseMemoryStore = "StormcloudUseMemoryStore"
    
    public func stringValue() -> String {
        return self.rawValue
    }
}

public protocol CoreDataStackFetchTemplate {
    func fetchRequestName() -> String
    
}

public protocol CoreDataStackDelegate {
    /**
     The location where you would like the SQLite database stored. Default is application document's directory, return nil to keep it there
     */
    func storeDirectory() -> URL?
}

open class CoreDataStack {
    
    open var delegate : CoreDataStackDelegate?
    
    /// If you have a store you want to copy from elsewhere (e.g. a default store in your bundle), set this before running `setupStore`
    open var copyDefaultStoreFromURL: URL?
    
    /// Whether to enable journalling on your SQLite database
    open var journalling: Bool = true
    
    /// The managed object context for this stack
    open var managedObjectContext : NSManagedObjectContext?
    
    internal var privateContext : NSManagedObjectContext?
    
    internal var callback : (() -> Void)?
    
    internal  let modelName : String
    
    internal var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    /**
     Initialises the core data stack, setting up the managed object model, the managed object contexts, and the persistent store coordinator.
     
     This method does NOT attach a persistent store to the coordinator. You will need to run setupStore in order to finish setting up the store.
     
     - parameter modelName: The name of the xcdatamodeld file to use. Also forms the basis for the name of the sqlite database
     
     */
    public init( modelName : String ) {
        self.modelName = modelName
        initialiseCoreData()
    }
    
    open func performRequestForTemplate( _ template : CoreDataStackFetchTemplate ) -> [NSManagedObject] {
        let results : [NSManagedObject]
        if let fetchRequest = self.persistentStoreCoordinator?.managedObjectModel.fetchRequestTemplate(forName: template.fetchRequestName()), let context = self.managedObjectContext {
            do {
                results = try context.fetch(fetchRequest) as! [NSManagedObject]
            } catch {
                results = []
                print("Error fetching unit")
            }
        } else {
            results = []
        }
        return results
    }
    
    /**
     Call this to finish setting up the store once you've set any additional properties.
     
     - parameter callback: The callback you want to run once the store is set up. Runs on the main thread.
     */
    open func setupStore(_ callback : (() -> Void)?) {
        
        self.callback = callback
		
		
        DispatchQueue.global(qos: .background).async {
            
            let storeURL = self.applicationDocumentsDirectory().appendingPathComponent("\(self.modelName).sqlite")
            
            //            sleep(400)
            
            // Try to copy the database from the bundle.
            if let defaultStoreURL = self.copyDefaultStoreFromURL {
                
                print("Attempting to copy store from: \(defaultStoreURL)\nto:\(storeURL)")
                do {
                    try FileManager.default.copyItem(at: defaultStoreURL, to: storeURL)
                } catch let error as NSError {
                    print("Store already exists")
                    if error.code != 516 {
                        print("Error copying store: \(error.localizedDescription), code: \(error.code)")
                    }
                } catch {
                    print("Unknown file error")
                }
            }
            
            if CoreDataStackEnvironmentVariables.UseMemoryStore.isEnabled() {
                do {
                    try self.persistentStoreCoordinator!.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: storeURL, options:self.storeOptions())
                    
                    print("Successfully attached in-memory store")
                    
                } catch let error as NSError {
                    print("Error adding in-memory persistent store: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                }
            } else {
                do {
                    try self.persistentStoreCoordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options:self.storeOptions())
                    
                    print("Successfully attached SQL store")
                    
                } catch let error as NSError {
                    print("Error adding SQL persistent store: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                }
            }

			if let callback = self.callback {
                DispatchQueue.main.sync(execute: { () -> Void in
                    callback()
                })
            }
        }
    }
    
    /**
     Saves the managed object contexts
     */
    open func save() {
        if self.managedObjectContext?.hasChanges == false && self.privateContext?.hasChanges == false {
            return
        }
        self.managedObjectContext?.performAndWait { () -> Void in
            do {
                try self.managedObjectContext?.save()
            } catch let error as NSError {
                print("Error: \(error.localizedDescription)\n\(error.userInfo)")
                abort()
            } catch {
                print("Error saving")
                abort()
            }
            
            self.privateContext?.perform({ () -> Void in
                do {
                    try self.privateContext?.save()
                } catch let error as NSError {
                    print("Error saving private context: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                } catch {
                    print("Error saving private context")
                    abort()
                }
            })
        }
    }
    
    
    
    @available(iOS 9.0, OSX 10.11, *)
    open func replaceStore() {
        save()
        let storeURL = self.applicationDocumentsDirectory().appendingPathComponent("\(self.modelName).sqlite")
        do {
            if let sourceStore = Bundle.main.url(forResource: self.modelName, withExtension: "sqlite") {
                try persistentStoreCoordinator?.replacePersistentStore(at: storeURL, destinationOptions: self.storeOptions(), withPersistentStoreFrom: sourceStore, sourceOptions: self.storeOptions(), ofType: NSSQLiteStoreType)
                print("Store replaced")
            } else {
                print("No replacement found")
            }
        } catch {
            print("Error deleting store")
        }
    }
    
    /**
     Use this for versions of iOS < 9.0 and OS X < 10.11 to delete the store files.
     */
    open func deleteStore() {
        save()
        
        print("Deleting store")
        
        managedObjectContext = nil
        privateContext = nil
        
        let storeURL = self.applicationDocumentsDirectory().appendingPathComponent("\(self.modelName).sqlite")
        
        if #available(OSX 10.9, *) {
            
            do {
                try  self.persistentStoreCoordinator?.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: self.storeOptions())
            } catch {
                print("Couldn't delete store")
            }
            
            
            persistentStoreCoordinator = nil
        } else {
            
            let walURL = self.applicationDocumentsDirectory().appendingPathComponent("\(self.modelName).sqlite-wal")
            let shmURL = self.applicationDocumentsDirectory().appendingPathComponent("\(self.modelName).sqlite-shm")
            
            
            do {
                try FileManager.default.removeItem(at: storeURL)
                try FileManager.default.removeItem(at: walURL)
                try FileManager.default.removeItem(at: shmURL)
            } catch let error as NSError {
                print("Error deleting store files: \(error.localizedDescription)")
            }
            
        }
        
        
        initialiseCoreData()
    }
    
    
    internal func storeOptions() -> [ NSObject : Any ] {
        var options = [ NSObject : Any ]()
//        options = [NSMigratePersistentStoresAutomaticallyOption as NSObject : true as Any]
        if !self.journalling {
            options[ NSSQLitePragmasOption as NSObject ] = [ "journal_mode" : "DELETE" ]
        }
        return options
    }
    
    internal func applicationDocumentsDirectory() -> URL {
        guard let theDelegate = delegate, let storeURL = theDelegate.storeDirectory() else {
			let thisSourceFile = URL(fileURLWithPath: #file)
			let thisDirectory = thisSourceFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources", isDirectory: true)
			return thisDirectory
        }
        return storeURL
    }
    
    internal func initialiseCoreData() {
        
        if self.managedObjectContext != nil {
            return
        }
        
        print("Setting up PSC")
        
//        let bundle = Bundle(for: CoreDataStack.self)

		let model = StormcloudTestModel()
		
//        guard let model = NSManagedObjectModel.mergedModel(from: [bundle]) else {
//            abort()
//        }
		self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model.setupModel())
        
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.privateContext!.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        self.managedObjectContext?.parent = privateContext
    }
    
    
    
}
























