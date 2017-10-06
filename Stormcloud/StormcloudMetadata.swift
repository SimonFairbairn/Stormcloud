//
//  StormcloudMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

public protocol StormcloudMetadataDelegate {
    func iCloudMetadataDidUpdate( _ metadata : StormcloudMetadata )
}

open class StormcloudMetadata : NSObject {
	open var delegate : StormcloudMetadataDelegate?
	// The date the item was added
	open var date : Date
	open var filename : String
	open var type : StormcloudDocumentType
	open var iCloudMetadata : NSMetadataItem? {
		didSet {
			self.delegate?.iCloudMetadataDidUpdate(self)
		}
	}

	/// A read only property indiciating whether or not the document currently exists in iCloud
	public var iniCloud : Bool {
		get {
			if let metadata = iCloudMetadata {
				if let isInCloud = metadata.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool {
					return isInCloud
				}
				
			}
			return false
		}
	}
	
	/// A read only property indicating that returns true when the document is currently downloading
	public var isDownloaded : Bool {
		get {
			if let metadata = iCloudMetadata {
				if let downloadingStatus = metadata.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
					return downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent
				}
			}
			return false
		}
	}
	
	/// A read only property indicating that returns true when the document is currently downloading
	public var isDownloading : Bool {
		get {
			if let metadata = iCloudMetadata {
				if let isDownloading = metadata.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool {
					return isDownloading
				}
			}
			return false
		}
	}
	
	/// A read only property that returns the percentage of the document that has downloaded
	public var percentDownloaded : Double {
		get {
			if let metadata = iCloudMetadata {
				if let downloaded = metadata.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double {
					return downloaded
				}
			}
			return 0.0
		}
	}
	
	/// A read only property indicating that returns true when the document is currently uploading
	public var isUploading : Bool {
		get {
			if let metadata = iCloudMetadata {
				if let isUploading = metadata.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool {
					return isUploading
				}
				
			}
			return false
		}
	}
	
	/// A read only property that returns the percentage of the document that has uploaded
	public var percentUploaded : Double {
		get {
			if let metadata = iCloudMetadata {
				if let uploaded = metadata.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double {
					return uploaded
				}
			}
			return 0.0
		}
	}
	
	override init() {
		self.filename = ""
		self.date = Date()
		self.type = .unknown
	}
	
	init( path : String ) {
		self.filename = path
		self.date = Date()
		self.type = .unknown
	}
	
	public convenience init( fileURL : URL ) {
		self.init(path : fileURL.lastPathComponent)
	}
	
	open override func isEqual(_ object: Any?) -> Bool {
		guard let isMetadata = object as? StormcloudMetadata else {
			return false
		}
		return isMetadata.filename == self.filename
	}
}








