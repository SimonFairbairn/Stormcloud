//
//  StormcloudMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

@objc
public protocol StormcloudMetadataDelegate {
    func iCloudMetadataDidUpdate( _ metadata : StormcloudMetadata )
}

open class StormcloudMetadata: NSObject {
    
    open static let dateFormatter = DateFormatter()
    
    /// A delegate that can be notified when the state of the backup document changes
    open var delegate : StormcloudMetadataDelegate?
	
	// The date the item was added
    open let date : Date
    
    /// The original Device UUID on which this backup was originally created
    open var deviceUUID : String
    open var device : String
    open var filename : String
    open var iCloudMetadata : NSMetadataItem? {
        didSet {
            self.delegate?.iCloudMetadataDidUpdate(self)
        }
    }
    
    /// A read only property indiciating whether or not the document currently exists in iCloud
    open var iniCloud : Bool {
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
    open var isDownloaded : Bool {
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
    open var isDownloading : Bool {
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
    open var percentDownloaded : Double {
        get {
            if let metadata = iCloudMetadata {
                if let downloaded = metadata.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double {
                    self.internalPercentDownloaded =  downloaded
                }
            }
            return self.internalPercentDownloaded
        }
    }
    
    /// A read only property indicating that returns true when the document is currently uploading
    open var isUploading : Bool {
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
    open var percentUploaded : Double {
        get {
            if let metadata = iCloudMetadata {
                if let uploaded = metadata.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double {
                    self.internalPercentUploaded =  uploaded
                }
            }
            return self.internalPercentUploaded
        }
    }
    
    var internalPercentUploaded : Double = 0
    var internalPercentDownloaded : Double = 0
    
    public override init() {
        let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        (dateComponents as NSDateComponents).calendar = NSCalendar.current
        (dateComponents as NSDateComponents).timeZone = TimeZone(abbreviation: "UTC")
        
        StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"

        self.device = UIDevice.current.model
        if let date = (dateComponents as NSDateComponents).date {
            self.date = date
        } else {
            self.date = Date()
        }
        
        self.deviceUUID = StormcloudMetadata.getDeviceUUID()
        let stringDate = StormcloudMetadata.dateFormatter.string(from: self.date)
        self.filename = "\(stringDate)--\(self.device)--\(self.deviceUUID).json"
    }
    
    
    public convenience init( fileURL : URL ) {
        self.init(path : fileURL.lastPathComponent)
    }
    

    public init( path : String ) {
        StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"

        var filename = ""
        
        var date  = Date()
        
        var device = UIDevice.current.model
        var deviceUUID = StormcloudMetadata.getDeviceUUID()
        
        filename = path
        let components = path.components(separatedBy: "--")
        
        if components.count > 2 {
            if let newDate = StormcloudMetadata.dateFormatter.date(from: components[0]) {
                date = newDate
            }
            
            device = components[1]
            deviceUUID = components[2].replacingOccurrences(of: ".json", with: "")
        }
        self.filename = filename
        self.device = device
        self.deviceUUID = deviceUUID
        self.date = date
    }
    
    
    /**
     Use this to get a UUID for the current device, which is then cached and attached to the filename of the created document and can be used to find out if the document that this metadata represents was originally created on the same device.
     
     - returns: The device UUID as a string
     */
    open class func getDeviceUUID() -> String {
        let currentDeviceUUIDKey = "VTADocumentsManagerDeviceKey"
        if let savedDevice = UserDefaults.standard.object(forKey: currentDeviceUUIDKey) as? String {
            return savedDevice
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.set(uuid, forKey: currentDeviceUUIDKey)
            return uuid
        }
    }
}

// MARK: - NSCopying 

extension StormcloudMetadata : NSCopying {
    public func copy(with zone: NSZone?) -> Any {
        let backup = StormcloudMetadata(path : self.filename)
        return backup
    }
}
