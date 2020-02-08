//
//  StormcloudTestsBaseClass.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest
import Stormcloud

class StormcloudTestsBaseClass: XCTestCase {
	enum ExpectationDescription : String {
		case positionTestAddItems
		case positionTestAddItems2
		case addTestBackup
		case addTestMetadataUpdates
		case delegateTestCorrectCounts
		case delegateTestThreeItems
		case addThenFindTest
		case maximumLimitsTestDidLoad
		case restoringTest
		case coreDataCreatesFileTest
		case imageFileReady
		case imagesReady
		case coreDataRestore
		case coreDataWeirdStrings
		case waitForFilesToBeReady
	}
	
	
	var stormcloudExpectation: XCTestExpectation?
	
	var fileExtension : String = "json"
    var docsURL : URL?
	var resourcesURL : URL?
	
	
    let futureFilename = "2020-10-19 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    let pastFilename = "2014-10-18 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    
    override func setUp() {
        super.setUp()
		docsURL = FileManager.default.temporaryDirectory
		let thisSourceFile = URL(fileURLWithPath: #file)
		resourcesURL = thisSourceFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources", isDirectory: true)
		deleteAllFiles()
	}
    
    override func tearDown() {		
		deleteAllFiles()

		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
    }
	
	
	
	func deleteAllFiles() {
		guard let docsDir = docsURL else {
			XCTFail("Couldn't get docs URL")
			return
		}
		
		var docs : [URL] = []
		do {
			docs = try FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
		} catch {
			fatalError("couldn't search path \(docsURL!): \(error)")
		}
		
		for url in docs {
			do {
				try FileManager.default.removeItem(at: url)
				print("Deleting \(url)")
			} catch {
				fatalError("Couldn't delete item")
			}
		}
		
	}
	
	
	func copyItemWith( filename: String, fileExtension : String ) {
		let fullName = filename + "." + fileExtension
		
		guard let resource = resourcesURL?.appendingPathComponent(fullName) else {
			XCTFail("Failed to get resourcesURL.")
			return
		}
		guard let docsURL = self.docsURL?.appendingPathComponent(fullName) else {
			XCTFail("Failed to get temporary directory.")
			return
		}
		do {
			try  FileManager.default.copyItem(at: resource, to: docsURL)
		} catch let error as NSError {
			XCTFail("Failed to copy past item \(error.localizedDescription)")
		}
	}
	
	
	
	func copyItems(extra : Bool = false) {		
		self.copyItemWith(filename: self.pastFilename, fileExtension: self.fileExtension)
		self.copyItemWith(filename: self.futureFilename, fileExtension: self.fileExtension)
		if extra {
			self.copyItemWith(filename: "fragment", fileExtension: self.fileExtension)
			
		}
    }
    
    
	func listItemsAtURL() -> [URL] {
        var jsonDocs : [URL] = []
        if let docsURL = docsURL {
            var docs : [URL] = []
            do {
                docs = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
            } catch {
                print("couldn't search path \(docsURL)")
            }
            
            for url in docs {
                if url.pathExtension == fileExtension {
                    jsonDocs.append(url)
                }
            }
        }
        return jsonDocs
    }
	
	func waitForFiles( _ stormcloud : Stormcloud ) {
		if !stormcloud.fileListLoaded {
			stormcloudExpectation = self.expectation(description: ExpectationDescription.waitForFilesToBeReady.rawValue)
			waitForExpectations(timeout: 15, handler: nil)
		}
	}
    
}

extension StormcloudTestsBaseClass : StormcloudDelegate {
	func stormcloudFileListDidLoad(_ stormcloud: Stormcloud) {
		
		guard let desc = stormcloudExpectation?.expectationDescription else {
			return
		}
		
		guard let expectationDescription = ExpectationDescription(rawValue:desc) else {
			XCTFail("Incorrect description")
			return
		}
		switch expectationDescription {
		case  .positionTestAddItems:
			stormcloudExpectation?.fulfill()
		case .waitForFilesToBeReady, .maximumLimitsTestDidLoad,
		     .restoringTest, .coreDataCreatesFileTest, .imagesReady, .coreDataRestore, .coreDataWeirdStrings:
			stormcloudExpectation?.fulfill()
		default:
			break
		}
	}
	
	func metadataDidUpdate(_ metadata: StormcloudMetadata, for type: StormcloudDocumentType) {
		
		
	}
	
	func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
		guard let desc = stormcloudExpectation?.expectationDescription else {
			return
		}
		
		guard let expectationDescription = ExpectationDescription(rawValue:desc) else {
			XCTFail("Incorrect description")
			return
		}
		
		switch expectationDescription {
		case .addTestBackup:
			if let hasItems = addedItems, hasItems.count == 1 {
				stormcloudExpectation?.fulfill()
			}
		case .addTestMetadataUpdates:
			if addedItems == nil && deletedItems == nil {
				stormcloudExpectation?.fulfill()
			}
		case .delegateTestCorrectCounts:
			if let hasItems = addedItems, hasItems.count == 2 {
				stormcloudExpectation?.fulfill()
			}
		case .delegateTestThreeItems, .imageFileReady:
			if let hasItems = addedItems, hasItems.count == 1 {
				stormcloudExpectation?.fulfill()
			}
		case .addThenFindTest:
			if let hasItems = addedItems, hasItems.count == 2 {
				stormcloudExpectation?.fulfill()
			}
		default:
			break
		}
		
		
	}
	
	public func metadataListDidChange(_ manager: Stormcloud) {
		print("List did change")
	}
	
}
