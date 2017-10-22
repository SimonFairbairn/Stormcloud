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


protocol DocumentProviderDelegate {
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
	var delegate: DocumentProviderDelegate?
	var pollingFrequecy: TimeInterval = 1 {
		didSet {
			self.metadataQuery.notificationBatchingInterval = pollingFrequecy
		}
	}
	
	var metadataQuery : NSMetadataQuery = NSMetadataQuery()
	
	init?() {
		let currentiCloudToken = FileManager.default.ubiquityIdentityToken
		
		// If we don't have a token, then we can't enable iCloud
		guard let token = currentiCloudToken  else {
			return nil
		}
		// Add observer for iCloud user changing
		NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.iCloudUserChanged(_:)), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
		
		let data = NSKeyedArchiver.archivedData(withRootObject: token)
		UserDefaults.standard.set(data, forKey: StormcloudPrefKey.iCloudToken.rawValue)
		UserDefaults.standard.set(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
		
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
			print("iCloud Document Provider found: \(obj ?? "No Object")")
			return true
		})
		
		NotificationCenter.default.addObserver(self, selector: #selector(iCloudDocumentProvider.updateFiles), name:NSNotification.Name.NSMetadataQueryDidFinishGathering , object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(iCloudDocumentProvider.updateFiles), name:NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
		
		self.metadataQuery.notificationBatchingInterval = pollingFrequecy
		self.metadataQuery.start()
	}
	
	func documentsDirectory() -> URL? {
		return FileManager.default.url(forUbiquityContainerIdentifier: nil)
	}
	
	@objc func updateFiles() {
		guard let items = self.metadataQuery.results as? [NSMetadataItem] else {
			return
		}
		
		print("iCloud Document Provider metadata query found \(items.count) items")
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
	
	
}

class LocalDocumentProvider : DocumentProvider {
	var delegate: DocumentProviderDelegate?
	var pollingFrequecy: TimeInterval = 2 {
		didSet {
			updateTimer()
		}
	}
	
	weak var timer : Timer?
	
	init() {
		updateTimer()
	}
	deinit {
		timer?.invalidate()
	}
	func updateTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(timeInterval: pollingFrequecy, target: self, selector: #selector(updateFiles), userInfo: nil, repeats: true)
	}
	
	@objc func updateFiles() {
		
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
