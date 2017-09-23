//
//  StormcloudImageTests.swift
//  StormcloudTests
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import XCTest

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
		let stormcloud = Stormcloud()
		
		XCTAssertEqual(stormcloud.metadataList.count, 0)
		
		XCTAssertFalse(stormcloud.isUsingiCloud)
		
		let docs = self.listItemsAtURL()
		XCTAssertEqual(stormcloud.metadataList.count, docs.count)
		let expectation = self.expectation(description: "Restoring item")
		
		let bundle = Bundle(for: StormcloudImageTests.self)
		
		
		guard  let imageURL = bundle.url(forResource: "TestItem1", withExtension: "jpg"), let image = UIImage(contentsOfFile: imageURL.path) else {
			XCTFail("Couldn't load image")
			return
		}
		XCTAssertNotNil(image)
		stormcloud.addDocument(withData: image , for: .jpegImage) { (error, metadata) in
			if let _ = error {
				XCTFail("Error creating document")
			} else {
				expectation.fulfill()
			}
		}
		
		
		waitForExpectations(timeout: 3.0, handler: nil)
		
		let newDocs = self.listItemsAtURL()
		XCTAssertEqual(newDocs.count, 1)
		XCTAssertEqual(stormcloud.metadataList.count, 1)
		XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
		
	}
    
}
