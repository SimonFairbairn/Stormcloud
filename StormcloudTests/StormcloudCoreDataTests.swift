//
//  StormcloudCoreDataTests.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import CoreData
import XCTest

enum StormcloudTestError : ErrorType {
    case InvalidContext
    case CouldntCreateManagedObject
}

class StormcloudCoreDataTests: StormcloudTestsBaseClass {

    let stack = CoreDataStack(modelName: "clouds")

    let manager = Stormcloud()
    
    override func setUp() {
         super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func insertCloudWithNumber(number : Int) throws -> Cloud {
        if let context = self.stack.managedObjectContext {
            do {
                let didRain : Bool? = ( number % 2 == 0 ) ? true : nil
                
                return try Cloud.insertCloudWithName("Cloud \(number)", order: number, didRain: didRain, inContext: context)
            } catch {
                XCTFail("Couldn't create cloud")
                throw StormcloudTestError.CouldntCreateManagedObject
            }
        } else {
            throw StormcloudTestError.InvalidContext
        }
    }
    
    func insertDropWithType(type : RaindropType, cloud : Cloud ) throws -> Raindrop {
        if let context = self.stack.managedObjectContext {
            do {
                return try Raindrop.insertRaindropWithType(type, withCloud: cloud, inContext: context)
            } catch {
                XCTFail("Couldn't create drop")
                throw StormcloudTestError.CouldntCreateManagedObject
            }
        } else {
            throw StormcloudTestError.InvalidContext
        }
    }
    

    func setupStack() {
        let expectation = expectationWithDescription("Stack Setup")
        stack.setupStore { () -> Void in
            XCTAssertNotNil(self.stack.managedObjectContext)
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
        
    }
    
    func addObjectsWithNumber(number : Int) {
        let cloud : Cloud
        do {
            cloud = try self.insertCloudWithNumber(number)
            _ = try? self.insertDropWithType(RaindropType.Heavy, cloud: cloud)
            _ = try? self.insertDropWithType(RaindropType.Light, cloud: cloud)
        } catch {
            XCTFail("Failed to create data")
        }
    }
    
    func backupCoreData() {
        guard let context = self.stack.managedObjectContext else {
            XCTFail("Context not available")
            return
        }
        let expectation = expectationWithDescription("Insert expectation")
        
        manager.backupCoreDataEntities(inContext: context) { (success, error, metadata) -> () in
            if !success {
                XCTFail("Failed to back up Core Data entites")
                
            }
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
    }
    
    func testThatBackingUpCoreDataCreatesFile() {
        
        self.setupStack()
        self.addObjectsWithNumber(1)
        self.backupCoreData()
        
        let items = self.listItemsAtURL()
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(self.manager.metadataList.count, 1)
    }
    
    func testThatBackingUpCoreDataCreatesCorrectFormat() {

        self.setupStack()
        self.addObjectsWithNumber(1)
        self.addObjectsWithNumber(2)
        self.backupCoreData()
        
        let items = self.listItemsAtURL()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(self.manager.metadataList.count, 1)
        
        let url = items[0]
        let data = NSData(contentsOfURL: url)
        
        var jsonObjects : AnyObject = [:]
        if let hasData = data {

            do {
                jsonObjects = try NSJSONSerialization.JSONObjectWithData(hasData, options: NSJSONReadingOptions.AllowFragments)
            } catch {
                XCTFail("Invalid JSON")
            }
        } else {
            XCTFail("Couldn't read data")
        }
        
        XCTAssertEqual(jsonObjects.count, 6)
        
        if let objects = jsonObjects as? [String : AnyObject]  {

            for (key, value) in objects {
                if key.containsString("Cloud") {
                    if let isDict = value as? [String : AnyObject], type = isDict[StormcloudEntityKeys.EntityType.rawValue] as? String {
                        XCTAssertEqual(type, "Cloud")

                        // Assert that the keys exist
                        XCTAssertNotNil(isDict["order"])
                        XCTAssertNotNil(isDict["added"])
                        
                        if let name = isDict["name"] as? String {

                            if let _ = isDict["didRain"] as? Int {
                                XCTAssertEqual(name, "Cloud 2")
                            } else {
                                XCTAssertEqual(name, "Cloud 1")
                            }
                            
                        } else {
                            XCTFail("Name poperty doesn't exist")
                        }
                        
                        if let value = isDict["chanceOfRain"] as? Float {
                            XCTAssertEqual(value, 0.45)
                        } else {
                            XCTFail("Chance of Rain poperty doesn't exist or is not float")
                        }
                        
                        if let relationship = isDict["raindrops"] as? [String] {
                            XCTAssertEqual(relationship.count, 2)
                        } else {
                            XCTFail("Relationship doesn't exist")
                        }
                        
                    } else {
                        XCTFail("Wrong type stored in dictionary")
                    }
                }
                
                if key.containsString("Raindrop") {
                    if let isDict = value as? [String : AnyObject], type = isDict[StormcloudEntityKeys.EntityType.rawValue] as? String {
                        
                        XCTAssertEqual(type, "Raindrop")
                        
                        if let _ = isDict["type"] as? String {
                            
                        } else {
                            XCTFail("Type poperty doesn't exist")
                        }
                        
                        if let _ = isDict["colour"] as? String {
                            
                        } else {
                            XCTFail("Colour poperty doesn't exist")
                        }

                        if let value = isDict["timesFallen"] as? NSNumber {
                            XCTAssertEqual(value, 10)
                        } else {
                            XCTFail("Times Fallen poperty doesn't exist or is not number")
                        }

                        if let decimalValue = isDict["raindropValue"] as? String {
                            XCTAssertEqual(decimalValue, "10.54")
                            
                        } else {
                            XCTFail("Value poperty doesn't exist or is not number")
                        }
                        
                        if let relationship = isDict["cloud"] as? [String] {
                            XCTAssertEqual(relationship.count, 1)
                            XCTAssert(relationship[0].containsString("Cloud"))
                        } else {
                            XCTFail("Relationship doesn't exist")
                        }
                    } else {
                        XCTFail("Wrong type stored in dictionary")
                    }
                }
            }
            
        } else {
            XCTFail("JSON object invalid")
        }
        
        // Read JSON
    }
    
    func testThatRestoringRestoresThingsCorrectly() {
        // Keep a copy of all the data and make sure it's the same when it gets back in to the DB
        
        self.setupStack()
        self.addObjectsWithNumber(1)
        self.addObjectsWithNumber(2)
        self.backupCoreData()
        
        let items = self.listItemsAtURL()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(self.manager.metadataList.count, 1)

        let expectation = expectationWithDescription("Restore expectation")
        manager.restoreCoreDataBackup(withMetadata: self.manager.metadataList[0], toContext: stack.managedObjectContext!) { (success) -> () in
            
            XCTAssertNil(success)
            XCTAssertEqual(NSThread.currentThread(), NSThread.mainThread())


            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(10.0, handler: nil)
        
        
        
        if let context = self.stack.managedObjectContext {
            
            let request = NSFetchRequest(entityName: "Cloud")
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            let clouds : [Cloud]
            do {
                clouds = try context.executeFetchRequest(request) as! [Cloud]
            } catch {
                clouds = []
            }
            
            XCTAssertEqual(clouds.count, 2)
            
            if clouds.count > 1  {
                let cloud1 = clouds[0]
                XCTAssertEqual(cloud1.raindrops?.count, 2)
                XCTAssertEqual(cloud1.name, "Cloud 1")
                XCTAssertEqual(cloud1.chanceOfRain, Float(0.45))
                XCTAssertNil(cloud1.didRain)
                
                if let raindrop = cloud1.raindrops?.anyObject() as? Raindrop {
                    
                    XCTAssertEqual(raindrop.raindropValue?.stringValue, "10.54")
                    XCTAssertEqual(raindrop.timesFallen, 10)
                }
                
                
                let cloud2 = clouds[1]
                
                if let raindrops = cloud2.raindrops?.allObjects {
                    XCTAssertEqual(raindrops.count, 2)
                }
                
                XCTAssertEqual(cloud2.name, "Cloud 2")
                XCTAssertEqual(cloud2.chanceOfRain, Float(0.45))
                
                if let bool = cloud2.didRain?.boolValue {
                    XCTAssert(bool)
                }
                
                if let raindrop = cloud2.raindrops?.anyObject() as? Raindrop {
                    
                    XCTAssertEqual(raindrop.cloud, cloud2)
                    XCTAssertEqual(raindrop.raindropValue?.stringValue, "10.54")
                    XCTAssertEqual(raindrop.timesFallen, 10)
                }
                
            } else {
                XCTFail("Not enough clouds in DB")
            }
        }
        
    }
    
    
    
}