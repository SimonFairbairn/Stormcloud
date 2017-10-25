//
//  StormcloudTests.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest
@testable import Stormcloud

class StormcloudTests: StormcloudTestsBaseClass {

	
	let year = NSCalendar.current.component(.year, from: Date())
	
	
	override func setUp() {
		fileExtension = "json"
		super.setUp()
	}
	
	override func tearDown() {
		stormcloudExpectation = nil
		super.tearDown()
	}
	
	
	func testThatBackupManagerAddsDocuments() {
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		XCTAssertEqual(stormcloud.items(for: .json).count, 0)
		XCTAssertFalse(stormcloud.isUsingiCloud)
		
		waitForFiles( stormcloud )
		
		let docs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, docs.count)
		
		stormcloudExpectation = self.expectation(description: ExpectationDescription.addTestBackup.rawValue)
		let expectation = self.expectation(description: "Backup Test")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { (error, metadata) -> () in
			XCTAssertNil(error, "Backing up should always write successfully")
			print(metadata?.filename ?? "No filename found")
			XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
			expectation.fulfill()
			
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(newDocs.count, 1)
		XCTAssertEqual(stormcloud.items(for: .json).count, 1)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
	}
	
	func testThatBackupManagerDeletesDocuments() {
		
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		
		
		waitForFiles( stormcloud )
		
		let expectation = self.expectation(description: "Backup expectation")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { (error, metadata) -> () in
			XCTAssertNil(error, "Backing up should always write successfully")
			
			print(metadata?.filename ?? "Filename doesn't exist")
			XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 1)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let deleteExpectation = self.expectation(description: "Delete expectation")
		
		if let firstItem = stormcloud.items(for: .json).first {
			stormcloud.deleteItem(firstItem) { (idx, error) -> () in
				XCTAssertNil(error)
				deleteExpectation.fulfill()
			}
		} else {
			XCTFail("Backup list should have at least 1 item in it")
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let emptyDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 0)
		XCTAssertEqual(stormcloud.items(for: .json).count, emptyDocs.count)
	}
	

	func testThatFindingNewItemsAfterCreatingDocumentWorksCorrectly() {
		fileExtension = "json"
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		waitForFiles( stormcloud )
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 0)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)

		// Add new item
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { ( error,  metadata) -> () in
			XCTAssertNil(error)
			XCTAssertEqual(stormcloud.items(for: .json).count, 1)
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		XCTAssertEqual(stormcloud.items(for: .json).count, 1)
		sleep(1)
		stormcloudExpectation = self.expectation(description: ExpectationDescription.addThenFindTest.rawValue)
		
		// Copy Items. Should be 2 additions when new items are found underneath existing one
		self.copyItems()
		waitForExpectations(timeout: 7, handler: nil)

		
		let threeDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 3)
		XCTAssertEqual(stormcloud.items(for: .json).count, threeDocs.count)
		if stormcloud.items(for: .json).count == 3 {
			XCTAssert(stormcloud.items(for: .json)[0].filename.contains("2020"))
			XCTAssert(stormcloud.items(for: .json)[1].filename.contains("\(self.year)"), stormcloud.items(for: .json)[1].filename)
			XCTAssert(stormcloud.items(for: .json)[2].filename.contains("2014"), stormcloud.items(for: .json)[2].filename)
		} else {
			XCTFail("Incorrect number of items")
		}
	}
	
	
	
	func testThatAddingAnItemPlacesItInRightPosition() {
		
		self.copyItems()
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		
		if !stormcloud.fileListLoaded {
			stormcloudExpectation = self.expectation(description: ExpectationDescription.positionTestAddItems.rawValue)
			waitForExpectations(timeout: 5, handler: nil)
		}
		
		
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
	
		
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { ( error,  metadata) -> () in
			
			XCTAssertNil(error)
			
			XCTAssertEqual(stormcloud.items(for: .json).count, 3)
			
			if stormcloud.items(for: .json).count == 3 {
				XCTAssert(stormcloud.items(for: .json)[0].filename.contains("2020"))
				XCTAssert(stormcloud.items(for: .json)[1].filename.contains("\(self.year)"), stormcloud.items(for: .json)[1].filename)
				XCTAssert(stormcloud.items(for: .json)[2].filename.contains("2014"), stormcloud.items(for: .json)[2].filename)
			} else {
				XCTFail("Incorrect number of items")
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let exp = self.expectation(description: "Delay")
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			exp.fulfill()
		}
		waitForExpectations(timeout: 3, handler: nil)
		
		let threeDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 3)
		XCTAssertEqual(stormcloud.items(for: .json).count, threeDocs.count)
	}
	
	func testThatFilenameDatesAreConvertedToLocalTime() {
		
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		waitForFiles( stormcloud )
		
		var dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
		dateComponents.timeZone = TimeZone(abbreviation: "UTC")
		dateComponents.calendar = NSCalendar.current
		guard let date = dateComponents.date else {
			XCTFail("Failed to get date from dateComponents")
			return
		}
		
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { (error,  metadata) -> () in
			
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
		stormcloud.delegate = self
		
		if !stormcloud.fileListLoaded {
			stormcloudExpectation = self.expectation(description: ExpectationDescription.maximumLimitsTestDidLoad.rawValue )
			waitForExpectations(timeout: 6, handler: nil)
		}
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { (error,  metadata) -> () in
			
			XCTAssertNil(error)
			
			XCTAssertEqual(stormcloud.items(for: .json).count, 3)
			
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let deleteExpectation = self.expectation(description: "Deleting new item")
		stormcloud.deleteItems(.json, overLimit: 2) { (error) in
			XCTAssertNil(error)
			XCTAssertEqual(stormcloud.items(for: .json).count, 2)
			deleteExpectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let stillTwoDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, stillTwoDocs.count)
		
		if stormcloud.items(for: .json).count == 2 {
			// It should delete the oldest one
			XCTAssert(stormcloud.items(for: .json)[0].filename.contains("2020"))
			XCTAssert(stormcloud.items(for: .json)[1].filename.contains("\(year)"), "Deleted the wrong file!")
		} else {
			XCTFail("Document number incorrect")
		}
	}
	
	func testThatRestoringAFileWorks() {
		fileExtension = "json"
		self.copyItems()
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		let newDocs = self.listItemsAtURL()
		
		if !stormcloud.fileListLoaded {
			stormcloudExpectation = self.expectation(description: ExpectationDescription.restoringTest.rawValue )
			waitForExpectations(timeout: 6, handler: nil)
		}

		
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let allItems = stormcloud.items(for: .json)
		guard allItems.count > 0 else {
			XCTFail("Not enough metadata items")
			return
		}
		
		let metadata = allItems[0]
		
		let expectation = self.expectation(description: "Restoring item")
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
	
	func testThatDelegatesWorkCorrectly() {
		
		// Start a new instance
		let stormcloud : Stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		// Copy items (stormcloud won't know because this happened after it was initialised)
		self.copyItems()
		
		if stormcloud.fileListLoaded {
			// Set expectation and reload
			stormcloudExpectation = self.expectation(description: ExpectationDescription.delegateTestCorrectCounts.rawValue)
			waitForExpectations(timeout: 3) { (error) in
				if let hasError = error {
					XCTFail(hasError.localizedDescription)
				}
			}
		} else {
			waitForFiles(stormcloud)
		}
		

		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		stormcloudExpectation = self.expectation(description: ExpectationDescription.delegateTestThreeItems.rawValue)
		let backupExpectation = expectation(description: "Backup")
		stormcloud.addDocument(withData: ["Test" : "Test"], for: .json) { (error, metadata) -> () in
			XCTAssertNil(error, "Backing up should always write successfully")
			print(metadata?.filename ?? "No filename found")
			XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
			backupExpectation.fulfill()
		}
		waitForExpectations(timeout: 3) { (error) in
			if let hasError = error {
				XCTFail(hasError.localizedDescription)
			}
		}

	}
}


