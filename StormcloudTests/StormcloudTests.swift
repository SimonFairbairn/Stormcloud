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
	
	var stormcloudExpectation: XCTestExpectation?
	let year = NSCalendar.current.component(.year, from: Date())
	
	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		stormcloudExpectation = nil
		super.tearDown()
	}
	
	
	func testThatBackupManagerAddsDocuments() {
		let stormcloud = Stormcloud()
		
		XCTAssertEqual(stormcloud.items(for: .json).count, 0)
		
		XCTAssertFalse(stormcloud.isUsingiCloud)
		
		let docs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, docs.count)
		
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
		XCTAssertEqual(stormcloud.items(for: .json).count, 1)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
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
		XCTAssertEqual(stormcloud.items(for: .json).count, 1)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let deleteExpectation = self.expectation(description: "Delete expectation")
		
		if let firstItem = stormcloud.items(for: .json).first {
			stormcloud.deleteItem(firstItem) { (error, index) -> () in
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
	
	
	
	func testThatAddingAnItemPlacesItInRightPosition() {
		
		self.copyItems()
		let stormcloud = Stormcloud()
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.backupObjectsToJSON(["Test" : "Test"]) { ( error,  metadata) -> () in
			
			XCTAssertNil(error)
			
			XCTAssertEqual(stormcloud.items(for: .json).count, 3)
			
			if stormcloud.items(for: .json).count == 3 {
				XCTAssert(stormcloud.items(for: .json)[0].filename.contains("2020"))
				XCTAssert(stormcloud.items(for: .json)[1].filename.contains("\(self.year)"))
				XCTAssert(stormcloud.items(for: .json)[2].filename.contains("2014"))
			}
			expectation.fulfill()
		}
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let threeDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 3)
		XCTAssertEqual(stormcloud.items(for: .json).count, threeDocs.count)
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
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		let expectation = self.expectation(description: "Adding new item")
		stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error,  metadata) -> () in
			
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
		self.copyItems()
		let stormcloud = Stormcloud()
		let newDocs = self.listItemsAtURL()
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
		let stormcloud = Stormcloud()
		stormcloud.delegate = self
		
		// Copy items (stormcloud won't know because this happened after it was initialised)
		self.copyItems()
		
		// Set expectation and reload
		stormcloudExpectation = self.expectation(description: "Correct Counts")
		stormcloud.reloadData()
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .json).count, 2)
		XCTAssertEqual(stormcloud.items(for: .json).count, newDocs.count)
		
		waitForExpectations(timeout: 3) { (error) in
			if let hasError = error {
				XCTFail(hasError.localizedDescription)
			}
		}
		
		stormcloudExpectation = self.expectation(description: "Three Items")
		let backupExpectation = expectation(description: "Backup")
		stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error, metadata) -> () in
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

extension StormcloudTests : StormcloudDelegate {
	func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
		
	}
	
	public func metadataListDidChange(_ manager: Stormcloud) {
		print("List did change")
	}
	public func metadataListDidAddItemsAtIndexes(_ addedItems: IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?) {
		guard let desc = stormcloudExpectation?.expectationDescription else {
			return
		}
		if let hasItems = addedItems, hasItems.count == 2, desc == "Correct Counts" {
			stormcloudExpectation?.fulfill()
		}
		if let hasItems = addedItems, hasItems.count == 3, desc == "Three Items" {
			stormcloudExpectation?.fulfill()
		}
	}
}
