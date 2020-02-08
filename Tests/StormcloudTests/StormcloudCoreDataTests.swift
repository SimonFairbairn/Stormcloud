//
//  StormcloudCoreDataTests.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import CoreData
import XCTest
@testable import Stormcloud

enum StormcloudTestError : Error {
    case invalidContext
    case couldntCreateManagedObject
}

class StormcloudCoreDataTests: StormcloudTestsBaseClass, StormcloudRestoreDelegate {

    let totalTags = 4
    let totalClouds = 2
    let totalRaindrops = 2
    
	var stack : CoreDataStack!
    
    override func setUp() {
		self.fileExtension = "json"
		stack = CoreDataStack(modelName: "clouds")
		super.setUp()
    }

    override func tearDown() {
		super.tearDown()
		
    }
    
    func insertCloudWithNumber(_ number : Int) throws -> Cloud {
        if let context = self.stack.managedObjectContext {
            do {
                let didRain : Bool? = ( number % 2 == 0 ) ? true : nil
                
                return try Cloud.insertCloudWithName("Cloud \(number)", order: number, didRain: didRain, inContext: context)
            } catch {
                XCTFail("Couldn't create cloud")
                throw StormcloudTestError.couldntCreateManagedObject
            }
        } else {
            throw StormcloudTestError.invalidContext
        }
    }
    
    func insertTagWithName(_ name : String ) throws -> Tag {
        if let context = self.stack.managedObjectContext {
            do {
                return try Tag.insertTagWithName(name, inContext: context)
            } catch {
                XCTFail("Couldn't create drop")
                throw StormcloudTestError.couldntCreateManagedObject
            }
        } else {
            throw StormcloudTestError.invalidContext
        }
        
    }
    
    func insertDropWithType(_ type : RaindropType, cloud : Cloud ) throws -> Raindrop {
        if let context = self.stack.managedObjectContext {
            do {
                return try Raindrop.insertRaindropWithType(type, withCloud: cloud, inContext: context)
            } catch {
                XCTFail("Couldn't create drop")
                throw StormcloudTestError.couldntCreateManagedObject
            }
        } else {
            throw StormcloudTestError.invalidContext
        }
    }
    
    
    
    func setupStack() {
        let expectation = self.expectation(description: "Stack Setup")
		
        stack.setupStore { () -> Void in
            XCTAssertNotNil(self.stack.managedObjectContext)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 4.0, handler: nil)
        
    }
    
    func addTags() -> [Tag] {
        print("Adding tags")
        
        var tags : [Tag] = []
        do {
            let tag1 = try self.insertTagWithName("Wet")
            let tag2 = try self.insertTagWithName("Windy")
            let tag3 = try self.insertTagWithName("Dark")
            let tag4 = try self.insertTagWithName("Thundery")
            
            tags.append(tag1)
            tags.append(tag2)
            tags.append(tag3)
            tags.append(tag4)
        } catch {
            XCTFail("Failed to insert tags")
        }
        return tags
    }
    
    func addObjectsWithNumber(_ number : Int, tags : [Tag] = []) {
        let cloud : Cloud
        do {
            cloud = try self.insertCloudWithNumber(number)
            let drop1 = try self.insertDropWithType(RaindropType.Heavy, cloud: cloud)
            let drop2 = try self.insertDropWithType(RaindropType.Light, cloud: cloud)

			cloud.addToRaindrops(drop1)
			cloud.addToRaindrops(drop2)
            if tags.count > 0 {
                cloud.tags = NSSet(array: tags)
            }
        } catch {
            XCTFail("Failed to create data: \(error)")
        }
        
    }
    
	func backupCoreData(with manager : Stormcloud) {
        guard let context = self.stack.managedObjectContext else {
            XCTFail("Context not available")
            return
        }
        let expectation = self.expectation(description: "Insert expectation")
        
        self.stack.save()
        manager.backupCoreDataEntities(in: context) { (error, metadata) -> () in
            if let _ = error {
                XCTFail("Failed to back up Core Data entites")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 4.0, handler: nil)
    }
	
	func test_setupCoreData() {
		let manager = Stormcloud()
		manager.delegate = self
		self.setupStack()
		let tags = self.addTags()
		self.addObjectsWithNumber(5, tags: tags)
		
		
	}
	
	func testThatBackingUpIndividualObjectsWorks() {
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
		self.setupStack()
		let tags = self.addTags()
		self.addObjectsWithNumber(5, tags: tags)
		
		waitForFiles(manager)
		
		guard let context = self.stack.managedObjectContext else {
			XCTFail("Context not available")
			return
		}

		self.stack.save()
		
		let expectation = self.expectation(description: "Insert expectation")
		let request = NSFetchRequest<Cloud>(entityName: "Cloud")
		
		let objects = try! context.fetch(request)
		
		manager.backupCoreDataObjects( objects: objects) { (error, metadata) -> () in
			if let hasError = error {
				XCTFail("Failed to back up Core Data entites: \(hasError)")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 30.0, handler: nil)
		let items = self.listItemsAtURL()
		
		XCTAssertEqual(items.count, 1)
		XCTAssertEqual(manager.items(for: .json).count, 1)
	

	}
	
	
    func testThatBackingUpCoreDataCreatesFile() {
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
        self.setupStack()
        self.addObjectsWithNumber(1)
		
		waitForFiles(manager)
		
        self.backupCoreData(with: manager)
        
        let items = self.listItemsAtURL()
        sleep(1)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(manager.items(for: .json).count, 1)
    }
    
    func testThatBackingUpCoreDataCreatesCorrectFormat() {
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
        self.setupStack()
        let tags = self.addTags()
		
		for i in 1...totalClouds {
			self.addObjectsWithNumber(i, tags:  tags)
		}
		
		waitForFiles(manager)
		
		self.backupCoreData(with: manager)
        let items = self.listItemsAtURL()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(manager.items(for: .json).count, 1)
        
        let url = items[0]
        let data = try? Data(contentsOf: url as URL)
        
        var jsonObjects : Any = [:]
        if let hasData = data {

            do {
                jsonObjects = try JSONSerialization.jsonObject(with: hasData, options: JSONSerialization.ReadingOptions.allowFragments)
            } catch {
                XCTFail("Invalid JSON")
            }
        } else {
            XCTFail("Couldn't read data")
        }
		
		
        XCTAssertEqual((jsonObjects as AnyObject).count, (totalRaindrops * totalClouds) + totalClouds + totalTags)
        
        if let objects = jsonObjects as? [String : AnyObject]  {

            for (key, value) in objects {
                if key.contains("Cloud") {
                    if let isDict = value as? [String : AnyObject], let type = isDict[StormcloudEntityKeys.EntityType.rawValue] as? String {
                        XCTAssertEqual(type, "Cloud")

                        // Assert that the keys exist
                        XCTAssertNotNil(isDict["order"])
                        XCTAssertNotNil(isDict["added"])
                        
                        if let name = isDict["name"] as? String , name == "Cloud 1" {

                            if let _ = isDict["didRain"] as? Int {
                                XCTFail("Cloud 1's didRain property should be nil")
                            } else {
                                XCTAssertEqual(name, "Cloud 1")
                            }
                            
                        }
                        
                        if let name = isDict["name"] as? String , name == "Cloud 2" {
                            
                            if let _ = isDict["didRain"] as? Int {
                                XCTAssertEqual(name, "Cloud 2")
                            } else {
                                XCTFail("Cloud 1's didRain property should be set")
                            }
                            
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
                
                if key.contains("Raindrop") {
                    if let isDict = value as? [String : AnyObject], let type = isDict[StormcloudEntityKeys.EntityType.rawValue] as? String {
                        
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
                            XCTAssert(relationship[0].contains("Cloud"))
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
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
		
		waitForFiles(manager)
		
		
        // Keep a copy of all the data and make sure it's the same when it gets back in to the DB
		// Give it a chance to catch up
        self.setupStack()
        let tags = self.addTags()
        self.addObjectsWithNumber(1, tags:  tags)
        self.addObjectsWithNumber(2, tags:  tags)
        self.backupCoreData(with: manager)
        
        let items = self.listItemsAtURL()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(manager.items(for: .json).count, 1)

		guard manager.items(for: .json).count > 0 else {
			XCTFail("Invalid number of items")
			return
		}
		
        let exp = self.expectation(description: "Restore expectation")
        manager.restoreCoreDataBackup(from: manager.items(for: .json)[0], to: stack.managedObjectContext!) { (success) -> () in
            
            XCTAssertNil(success)
            XCTAssertEqual(Thread.current, Thread.main)


            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        if let context = self.stack.managedObjectContext {
            
            let request = NSFetchRequest<Cloud>(entityName: "Cloud")
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            let clouds : [Cloud]
            do {
                clouds = try context.fetch(request)
            } catch {
                clouds = []
            }
            
            XCTAssertEqual(clouds.count, 2)
            
            if clouds.count > 1  {
                let cloud1 = clouds[0]
                XCTAssertEqual(cloud1.tags?.count, totalTags)
                XCTAssertEqual(cloud1.raindrops?.count, totalRaindrops)
                XCTAssertEqual(cloud1.name, "Cloud 1")
				XCTAssertEqual(cloud1.chanceOfRain?.floatValue, Float( 0.45))
                XCTAssertNil(cloud1.didRain)
                
                if let raindrop = cloud1.raindrops?.anyObject() as? Raindrop {
                    
                    XCTAssertEqual(raindrop.raindropValue?.stringValue, "10.54")
                    XCTAssertEqual(raindrop.timesFallen, 10)
                }
                
                
                let cloud2 = clouds[1]
                XCTAssertEqual(cloud2.tags?.count, totalTags)
                if let raindrops = cloud2.raindrops?.allObjects {
                    XCTAssertEqual(raindrops.count, totalRaindrops)
                }
                
                XCTAssertEqual(cloud2.name, "Cloud 2")
                XCTAssertEqual(cloud2.chanceOfRain?.floatValue, Float(0.45))
                
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
    

	func testThatRestoringIndividualItemsWorks() {
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
		// Keep a copy of all the data and make sure it's the same when it gets back in to the DB
		self.copyItems(extra: true)
		self.setupStack()
		let items = self.listItemsAtURL()
		
		waitForFiles(manager)
		
		XCTAssertEqual(items.count, 3)
		
		manager.restoreDelegate = self
		
		guard let context = stack.managedObjectContext else {
			XCTFail("Context not ready")
			return
		}
		
		guard let file = items.filter( { $0.path.contains("fragment") } ).first else {
			XCTFail("Couldn't find correct file")
			return
		}

		do {
			let jsonData = try Data(contentsOf: file)
			let json = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
			
			if let isJSON = json as? [String : AnyObject] {
				let exp = expectation(description: "Individual Restore Expectation")
				manager.insertIndividualObjectsWithContext(context, data: isJSON, completion: { (success) in
					
					guard success else {
						XCTFail("Failed to restore objects")
						return
					}

					let request = NSFetchRequest<Cloud>(entityName: "Cloud")
					let objects = try! context.fetch(request)
					
					XCTAssertEqual(objects.count, 1)
					
					if let cloud = objects.first {
						XCTAssertEqual(cloud.raindrops!.count, 2)
						
						if let raindrops = cloud.raindrops as? Set<Raindrop> {
							let heavy = raindrops.filter() { $0.type == "Heavy" }
							XCTAssertEqual(heavy.count, 1, "There should be one heavy raindrop")
						}
						
					}
					
					
					
					exp.fulfill()
					
				})
				waitForExpectations(timeout: 3, handler: nil)
			} else {
				XCTFail("Invalid Format")
			}
			
		} catch {
			XCTFail("Failed to read contents")
		}
		

		
	}
	

	
    func testWeirdStrings() {
        // Keep a copy of all the data and make sure it's the same when it gets back in to the DB
		let manager = Stormcloud(with: TestDocumentProvider())
		manager.delegate = self
        self.setupStack()
		if let context = self.stack.managedObjectContext {
			
			let request = NSFetchRequest<Cloud>(entityName: "Cloud")
			request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
			let clouds : [Cloud]
			do {
				clouds = try context.fetch(request)
			} catch {
				clouds = []
			}
			
			XCTAssertEqual(clouds.count, 0)			
		}

        if let context = self.stack.managedObjectContext {
            do {
                _ = try Cloud.insertCloudWithName("\("String \" With 😀🐼🐵⸘&§@$€¥¢£₽₨₩৲₦₴₭₱₮₺฿৳૱௹﷼₹₲₪₡₥₳₤₸₢₵៛₫₠₣₰₧₯₶₷")", order: 0, didRain: true, inContext: context)
            } catch {
                print("Error inserting cloud")
            }
			
			
        }
		
		waitForFiles(manager)
		
        self.backupCoreData(with: manager)
		
        let items = self.listItemsAtURL()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(manager.items(for: .json).count, 1)
		
		guard items.count == 1 else {
			XCTFail("Incorrect count for items")
			return
		}
		
		print(manager.urlForItem(manager.items(for: .json)[0]) ?? "No metadata item found")
        
        let expectation = self.expectation(description: "Restore expectation")
        manager.restoreCoreDataBackup(from: manager.items(for: .json)[0], to: stack.managedObjectContext!) { (success) -> () in
            
            XCTAssertNil(success)
            XCTAssertEqual(Thread.current, Thread.main)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0, handler: nil)
        
        if let context = self.stack.managedObjectContext {
            
            let request = NSFetchRequest<Cloud>(entityName: "Cloud")
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            let clouds : [Cloud]
            do {
                clouds = try context.fetch(request)
            } catch {
                clouds = []
            }
            
            XCTAssertEqual(clouds.count, 1)
            
            if clouds.count == 1  {
                let cloud1 = clouds[0]
                
                XCTAssertEqual("\("String \" With 😀🐼🐵⸘&§@$€¥¢£₽₨₩৲₦₴₭₱₮₺฿৳૱௹﷼₹₲₪₡₥₳₤₸₢₵៛₫₠₣₰₧₯₶₷")", cloud1.name)
                
                
            }
        }
    }

	func stormcloud(stormcloud: Stormcloud, shouldRestore objects: [String : AnyObject], toEntityWithName name: String) -> Bool {
		return true
	}
    
}
