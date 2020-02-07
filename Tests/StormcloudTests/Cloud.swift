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
            cloud.added = Date()
            cloud.chanceOfRain = 0.45
			
			if let hasImage = UIImage(named: "cloud"), let data = hasImage.jpegData(compressionQuality: 0.7)  {
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

extension Cloud {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Cloud> {
        return NSFetchRequest<Cloud>(entityName: "Cloud")
    }

    @NSManaged public var added: Date?
    @NSManaged public var chanceOfRain: NSNumber?
    @NSManaged public var didRain: NSNumber?
    @NSManaged public var image: Data?
    @NSManaged public var name: String?
    @NSManaged public var order: NSNumber?
    @NSManaged public var raindrops: NSSet?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for raindrops
extension Cloud {

    @objc(addRaindropsObject:)
    @NSManaged public func addToRaindrops(_ value: Raindrop)

    @objc(removeRaindropsObject:)
    @NSManaged public func removeFromRaindrops(_ value: Raindrop)

    @objc(addRaindrops:)
    @NSManaged public func addToRaindrops(_ values: NSSet)

    @objc(removeRaindrops:)
    @NSManaged public func removeFromRaindrops(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension Cloud {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}
