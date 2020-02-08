//
//  StormcloudImageTests.swift
//  StormcloudTests
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import XCTest
@testable import Stormcloud

class StormcloudImageTests: StormcloudTestsBaseClass {

	
    override func setUp() {
        super.setUp()
		self.fileExtension = "jpg"
        // Put setup code here. This method is called before the invocation of each test method in the class.

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
	func testThatBackupManagerAddsDocuments() {
		let stormcloud = Stormcloud(with: TestDocumentProvider())
		stormcloud.delegate = self
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, 0)
		XCTAssertFalse(stormcloud.isUsingiCloud)

		
		if !stormcloud.fileListLoaded {
			stormcloudExpectation = self.expectation(description: ExpectationDescription.imagesReady.rawValue)
			waitForExpectations(timeout: 5, handler: nil)
		}
		
		let docs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, docs.count)
		let expectation = self.expectation(description: "Restoring item")
		
		guard let imageURL = resourcesURL?.appendingPathComponent("TestItem1.jpg"),
			let image = UIImage(contentsOfFile: imageURL.path) else {
			XCTFail("Couldn't load image")
			expectation.fulfill()
			return
		}
		XCTAssertNotNil(image)
		stormcloud.addDocument(withData: image , for: .jpegImage) { (error, metadata) in
			if let _ = error {
				XCTFail("Error creating document")
			}
			expectation.fulfill()
		}
		
		waitForExpectations(timeout: 6.0, handler: nil)
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(newDocs.count, 1)
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, 1)
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, newDocs.count)
		stormcloud.delegate = nil
	}
	
	func testThatManuallyCreatedDocumentsGetDeleted() {
		let stormcloud = Stormcloud(with: TestDocumentProvider())
		stormcloud.delegate = self
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, 0)
		XCTAssertFalse(stormcloud.isUsingiCloud)

		guard let imageURL = resourcesURL?.appendingPathComponent("TestItem1.jpg"),
			let imageDestination = docsURL?.appendingPathComponent("TestItem1.jpg") else {
			XCTFail("Couldn't load image")
			return
		}
		do {
			try FileManager.default.copyItem(at: imageURL, to: imageDestination)
		} catch {
			XCTFail("Failed to copy image to documents directory")
		}
		
		stormcloudExpectation = expectation(description: ExpectationDescription.imageFileReady.rawValue)
		waitForExpectations(timeout: 3, handler: nil)
		XCTAssertEqual(stormcloud.items(for: .jpegImage).filter() { $0 is JPEGMetadata }.count, 1)

		let item = JPEGMetadata(path: "TestItem1.jpg")
		
		let exp = expectation(description: "Deletion")
		stormcloud.deleteItem(item) { (index, error) in
			if let hasError = error {
				XCTFail("Failed to delete: \(hasError.localizedDescription)")
			}
		}
		
		// Give the coordinator time to delete the file
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			XCTAssertFalse(FileManager.default.fileExists(atPath: imageDestination.path))
			exp.fulfill()
		}
		waitForExpectations(timeout: 4, handler: nil)
		
		XCTAssertEqual(stormcloud.items(for: .jpegImage).count, 0)
		stormcloud.delegate = nil
	}
	
}
