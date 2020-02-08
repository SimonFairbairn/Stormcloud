//
//  File.swift
//  
//
//  Created by Simon Fairbairn on 08/02/2020.
//

import Foundation
@testable import Stormcloud

class TestDocumentProvider : DocumentProvider {
	weak var delegate: DocumentProviderDelegate?
	var pollingFrequecy: TimeInterval = 2 {
		didSet {
			updateTimer()
		}
	}
	
	var count = 0
	weak var timer : Timer?
	
	init() {
		updateTimer()
	}
	deinit {
		print("Provider deinit called")
	}
	func updateTimer() {
		
		Timer.scheduledTimer(timeInterval: pollingFrequecy, target: self, selector: #selector(self.timerHit(_:)), userInfo: nil, repeats: true)
	}
	
	@objc func timerHit( _ timer : Timer ) {
		if let _ = delegate {
			updateFiles()
		} else {
			timer.invalidate()
		}
	}
	
	
	@objc func updateFiles( ) {
		

		assert(Thread.current == Thread.main)
		
		if StormcloudEnvironment.DelayLocal.isEnabled() {
			count = count + 1
			if count < 2 {
				return
			}
		}
		
		guard let docsDir = documentsDirectory() else {
			return
		}
		
		let items : [URL]
		do {
			items = try FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
		} catch {
			print("Error reading items: \(#file)")
			items = []
		}
		
		let availableTypes = Dictionary(grouping: items) {
			return $0.pathExtension
		}
		
		var sortedItems = [StormcloudDocumentType : [StormcloudMetadata]]()
		for type in StormcloudDocumentType.allTypes() {
			if let hasItems = availableTypes[type.rawValue] {
				if type == .json {
					sortedItems[type] = hasItems.map() { JSONMetadata(fileURL: $0 )}
				} else if type == .jpegImage {
					sortedItems[type] = hasItems.map() { JPEGMetadata(fileURL: $0 )}
				}
			}
		}
		
		delegate?.provider(self, didFindItems: sortedItems)
	}
	
	func documentsDirectory() -> URL? {
		return FileManager.default.temporaryDirectory
	}
}
