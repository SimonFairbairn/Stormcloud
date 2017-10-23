//
//  DocumentProviders.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 22/10/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import Foundation

public enum StormcloudDocumentType : String {
	case unknown = ""
	case json = "json"
	case jpegImage = "jpg"
	case pngImage = "png"
	
	static func allTypes() -> [StormcloudDocumentType] {
		return [.unknown, .json, .jpegImage, .pngImage]
	}
	public init?(rawValue : String ) {
		if rawValue == "json" {
			self = .json
		} else if rawValue == "jpg" {
			self = .jpegImage
		} else if rawValue == "png" {
			self = .pngImage
		} else if rawValue == "" {
			self = .unknown
		} else {
			return nil
		}
	}
}


protocol DocumentProviderDelegate : class {
	func provider( _ prov : DocumentProvider, didFindItems items : [StormcloudDocumentType : [StormcloudMetadata]])
	func provider( _ prov : DocumentProvider, didDelete item : URL)
}

protocol DocumentProvider {
	var delegate : DocumentProviderDelegate? {
		get set
	}
	var pollingFrequecy : TimeInterval {
		get set
	}
	
	func documentsDirectory() -> URL?
	func updateFiles()
}

class iCloudDocumentProvider : DocumentProvider {
	let token = FileManager.default.ubiquityIdentityToken
	weak var delegate: DocumentProviderDelegate?
	var finishedInitialUpdate = false
	var pollingFrequecy: TimeInterval = 0.3 {
		didSet {
			self.metadataQuery.notificationBatchingInterval = pollingFrequecy
		}
	}
	
	var metadataQuery : NSMetadataQuery = NSMetadataQuery()
	
	init?() {
		// If we don't have a token, then we can't enable iCloud
		guard let _ = token  else {
			return nil
		}
		// Add observer for iCloud user changing
		NotificationCenter.default.addObserver(self, selector: #selector(self.iCloudUserChanged(_:)), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
		
		// Start the metadata query
		if metadataQuery.isStopped {
			print("iCloud Document Provider starting metadata query")
			metadataQuery.start()
			return
		}
		
		if metadataQuery.isGathering {
			print("iCloud Document Provider query gathering")
			return
		}
		
		metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
		//		let types = StormcloudDocumentType.allTypes().map() { return $0.rawValue }
		metadataQuery.predicate = NSPredicate.init(block: { (obj, _) -> Bool in
			return true
		})
		
		NotificationCenter.default.addObserver(self, selector: #selector(iCloudDocumentProvider.finishedGather), name:NSNotification.Name.NSMetadataQueryDidFinishGathering , object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(iCloudDocumentProvider.updateFiles), name:NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
		
		self.metadataQuery.notificationBatchingInterval = pollingFrequecy
		self.metadataQuery.start()
	}
	
	func documentsDirectory() -> URL? {
		return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
	}
	
	@objc func finishedGather() {
		finishedInitialUpdate = true
		updateFiles()
	}
	
	@objc func updateFiles() {
		guard let items = self.metadataQuery.results as? [NSMetadataItem] else {
			return
		}
		guard finishedInitialUpdate else {
			return
		}
		
		var allBackups = [StormcloudMetadata]()
		for item in items {
			if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
				let validMetadata = StormcloudDocumentType.init(rawValue: url.pathExtension) {
				
				let backup : StormcloudMetadata?
				switch validMetadata {
				case .json:
					backup = JSONMetadata(fileURL: url)
				case .jpegImage:
					backup = JPEGMetadata(fileURL: url)
				case .pngImage, .unknown:
					backup = nil
				}
				if let hasBackup = backup {
					hasBackup.iCloudMetadata = item
					allBackups.append(hasBackup)
				}
				
			}
		}
		
		let availableTypes = Dictionary(grouping: allBackups) {
			return $0.type
		}
		
		self.delegate?.provider(self, didFindItems: availableTypes)
		
	}
	
	@objc func iCloudUserChanged( _ notification : Notification ) {
		// Handle user changing
	}
	deinit {
		self.metadataQuery.stop()
		NotificationCenter.default.removeObserver(self)
	}
	
}

class LocalDocumentProvider : DocumentProvider {
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
			print("Error reading items")
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
		return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
	}
}
