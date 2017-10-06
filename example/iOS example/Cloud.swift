//
//  Cloud.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

@objc(Cloud)
open class Cloud: NSManagedObject {
	
	// Insert code here to add functionality to your managed object subclass
	
	open class func insertCloudWithName(_ name : String, order : Int, didRain : Bool?, inContext context : NSManagedObjectContext ) throws -> Cloud {
		if let cloud = NSEntityDescription.insertNewObject(forEntityName: "Cloud", into: context) as? Cloud {
			cloud.name = name
			cloud.order = NSNumber(value: order)
			if let didRainSet = didRain {
				cloud.didRain = NSNumber(value:didRainSet )
			}
			cloud.added = NSDate()
			cloud.chanceOfRain = 0.45
			
			if let hasImage = UIImage(named: "cloud"), let data = UIImageJPEGRepresentation(hasImage, 0.7) as NSData? {
				cloud.image = data
			}
			
			return cloud
		} else {
			throw ICECoreDataError.invalidType
		}
	}
	
	open func raindropsForType( _ type : RaindropType) -> [Raindrop] {
		var raindrops : [Raindrop] = []
		
		if let hasRaindrops = self.raindrops?.allObjects as? [Raindrop] {
			raindrops =  hasRaindrops.filter() { $0.type == type.rawValue  }
		}
		return raindrops
	}
	
}

