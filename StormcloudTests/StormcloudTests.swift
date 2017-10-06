//
//  StormcloudTests.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest

class StormcloudTests: StormcloudTestsBaseClass {
	
	let year = NSCalendar.current.component(.year, from: Date())
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testThatBackupManagerAddsDocuments() {
        let stormcloud = Stormcloud()
        
        XCTAssertEqual(stormcloud.metadataList.count, 0)
        
        XCTAssertFalse(stormcloud.isUsingiCloud)
        
        let docs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, docs.count)
        
        let expectation = self.expectation(description: "Backup expectation")
        
        
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error, metadata) -> () in
            XCTAssertNil(error, "Backing up should always write successfully")
			print(metadata?.filename ?? "No filename found")
                XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
            expectation.fulfill()
            
        }
        
        waitForExpectations(timeout: 3.0, handler: nil)
        
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(newDocs.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
        
    }
    
    func testThatBackupManagerDeletesDocuments() {
        let stormcloud = Stormcloud()
        
        let expectation = self.expectation(description: "Backup expectation")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error, metadata) -> () in
            XCTAssertNil(error, "Backing up should always write successfully")

			print(metadata?.filename ?? "Filename doesn't exist")
                XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0, handler: nil)
        
        
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)

        let deleteExpectation = self.expectation(description: "Delete expectation")
        
        if let firstItem = stormcloud.metadataList.first {
            stormcloud.deleteItem(firstItem) { (error, index) -> () in
                XCTAssertNil(error)
                deleteExpectation.fulfill()
            }
        } else {
            XCTFail("Backup list should have at least 1 item in it")
        }
        waitForExpectations(timeout: 3.0, handler: nil)
        
        let emptyDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 0)
        XCTAssertEqual(stormcloud.metadataList.count, emptyDocs.count)
    }
	

    
    func testThatAddingAnItemPlacesItInRightPosition() {
        
        self.copyItems()
        let stormcloud = Stormcloud()
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
	
        let expectation = self.expectation(description: "Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { ( error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            XCTAssertEqual(stormcloud.metadataList.count, 3)

            if stormcloud.metadataList.count == 3 {
                XCTAssert(stormcloud.metadataList[0].filename.contains("2020"))
                XCTAssert(stormcloud.metadataList[1].filename.contains("\(self.year)"))
                XCTAssert(stormcloud.metadataList[2].filename.contains("2014"))
                
            }
            
        
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0, handler: nil)
        
        let threeDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 3)
        XCTAssertEqual(stormcloud.metadataList.count, threeDocs.count)
        
    }
	

    
    func testThatFilenameDatesAreConvertedToLocalTime() {
        
        let stormcloud = Stormcloud()
        var dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        dateComponents.timeZone = TimeZone(abbreviation: "UTC")
        dateComponents.calendar = NSCalendar.current
        guard let date = dateComponents.date else {
            XCTFail("Failed to get date from dateComponents")
            return
        }
        
        let expectation = self.expectation(description: "Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            if let hasMetadata = metadata {
                let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: hasMetadata.date)
                (dateComponents as NSDateComponents).calendar = NSCalendar.current
                if let metaDatadate = (dateComponents as NSDateComponents).date {
                    XCTAssertEqual(date, metaDatadate)
                }
            }
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0, handler: nil)
        
    }
    
    
    func testThatMaximumBackupLimitsAreRespected() {
        self.copyItems()
        let stormcloud = Stormcloud()

        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)

        let expectation = self.expectation(description: "Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            XCTAssertEqual(stormcloud.metadataList.count, 3)
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0, handler: nil)
		
        let deleteExpectation = self.expectation(description: "Deleting new item")
		stormcloud.deleteItems(.json, overLimit: 2) { (error) in
			XCTAssertNil(error)
			XCTAssertEqual(stormcloud.metadataList.count, 2)
			deleteExpectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
        let stillTwoDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, stillTwoDocs.count)
        
        if stormcloud.metadataList.count == 2 {
            // It should delete the oldest one
            XCTAssert(stormcloud.metadataList[0].filename.contains("2020"))
            XCTAssert(stormcloud.metadataList[1].filename.contains("\(year)"), "Deleted the wrong file!")
        } else {
            XCTFail("Document number incorrect")
        }
    }
    
    func testThatRestoringAFileWorks() {
        self.copyItems()
        let stormcloud = Stormcloud()
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
        let expectation = self.expectation(description: "Restoring item")        
        
        let metadata = stormcloud.metadataList[0]
        
        stormcloud.restoreBackup(withMetadata: metadata) { (error, restoredObjects) -> () in
            XCTAssertNil(error)
            
            XCTAssertNotNil(restoredObjects)
            
            if let dictionary = restoredObjects as? [String : AnyObject], let model = dictionary["Model"] as? String {
                XCTAssertEqual(model, "iPhone")
                
            } else {
                XCTFail("Restored objects not valid")
            }
            
            expectation.fulfill()
            
        }
        
        waitForExpectations(timeout: 4.0, handler: nil)
        
    }
    
    
}
