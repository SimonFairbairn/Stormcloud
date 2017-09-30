//
//  JSONMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

open class JSONMetadata: StormcloudMetadata {
	
	
	open static let dateFormatter = DateFormatter()
	

	/// The original Device UUID on which this backup was originally created
	open var deviceUUID : String
	open var device : String
	
	public override init() {
		self.device = UIDevice.current.model
		self.deviceUUID = JSONMetadata.getDeviceUUID()
		super.init()
		let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
		(dateComponents as NSDateComponents).calendar = NSCalendar.current
		(dateComponents as NSDateComponents).timeZone = TimeZone(abbreviation: "UTC")
		
		JSONMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
		
		
		if let date = (dateComponents as NSDateComponents).date {
			self.date = date
		} else {
			self.date = Date()
		}
		
		
		let stringDate = JSONMetadata.dateFormatter.string(from: self.date)
		self.filename = "\(stringDate)--\(self.device)--\(self.deviceUUID).json"
		self.type = .json
	}
	
	

	
	public override init( path : String ) {
		JSONMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
		
		var filename = ""
		
		var date  = Date()
		
		var device = UIDevice.current.model
		var deviceUUID = JSONMetadata.getDeviceUUID()
		
		filename = path
		let components = path.components(separatedBy: "--")
		
		if components.count > 2 {
			if let newDate = JSONMetadata.dateFormatter.date(from: components[0]) {
				date = newDate
			}
			
			device = components[1]
			deviceUUID = components[2].replacingOccurrences(of: ".json", with: "")
		}
		
		self.device = device
		self.deviceUUID = deviceUUID
		
		super.init()
		self.filename = filename
		self.date = date
		self.type = .json
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

extension JSONMetadata : NSCopying {
	public func copy(with zone: NSZone?) -> Any {
		let backup = JSONMetadata(path : self.filename)
		return backup
	}
}
