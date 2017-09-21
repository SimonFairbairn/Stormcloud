//
//  ImageMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

//class ImageMetadata: StormcloudMetadata {
//	public override init() {
//		let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
//		(dateComponents as NSDateComponents).calendar = NSCalendar.current
//		(dateComponents as NSDateComponents).timeZone = TimeZone(abbreviation: "UTC")
//		
//		StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
//		
//		self.device = UIDevice.current.model
//		if let date = (dateComponents as NSDateComponents).date {
//			self.date = date
//		} else {
//			self.date = Date()
//		}
//		
//		self.deviceUUID = StormcloudMetadata.getDeviceUUID()
//		let stringDate = StormcloudMetadata.dateFormatter.string(from: self.date)
//		self.filename = "\(stringDate)--\(self.device)--\(self.deviceUUID).json"
//	}
//	
//	
//	public override init( path : String ) {
//		StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
//		
//		var filename = ""
//		
//		var date  = Date()
//		
//		var device = UIDevice.current.model
//		var deviceUUID = StormcloudMetadata.getDeviceUUID()
//		
//		filename = path
//		let components = path.components(separatedBy: "--")
//		
//		if components.count > 2 {
//			if let newDate = StormcloudMetadata.dateFormatter.date(from: components[0]) {
//				date = newDate
//			}
//			
//			device = components[1]
//			deviceUUID = components[2].replacingOccurrences(of: ".json", with: "")
//		}
//		self.filename = filename
//		self.device = device
//		self.deviceUUID = deviceUUID
//		self.date = date
//	}
//}

