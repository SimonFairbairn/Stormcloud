//
//  JSONMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

open class JSONMetadata: StormcloudMetadata {
	
	
	public static let dateFormatter = DateFormatter()
	
	/// The name of the device
	open var device : String
	
	public override init() {
		self.device = UIDevice.current.model
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
		self.filename = "\(stringDate)--\(self.device).json"
		self.type = .json
	}
	
	

	
	public override init( path : String ) {
		JSONMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
		
		var filename = ""
		
		var date  = Date()
		
		var device = UIDevice.current.name
		
		filename = path
		let components = path.components(separatedBy: "--")
		
		if components.count > 1 {
			if let newDate = JSONMetadata.dateFormatter.date(from: components[0]) {
				date = newDate
			}
			
			device = components[1].replacingOccurrences(of: ".json", with: "")
		}
		
		self.device = device
		
		super.init()
		self.filename = filename
		self.date = date
		self.type = .json
	}

}

// MARK: - NSCopying

extension JSONMetadata : NSCopying {
	public func copy(with zone: NSZone?) -> Any {
		let backup = JSONMetadata(path : self.filename)
		return backup
	}
}
