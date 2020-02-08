//
//  Tag.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 02/11/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData


open class Tag: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    open class func insertTagWithName(_ name : String, inContext context : NSManagedObjectContext ) throws -> Tag {
        if let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: context) as? Tag {
            tag.name = name
            return tag
        } else {
            throw ICECoreDataError.invalidType
        }
    }
    
}


extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var name: String?
    @NSManaged public var clouds: NSSet?

}

// MARK: Generated accessors for clouds
extension Tag {

    @objc(addCloudsObject:)
    @NSManaged public func addToClouds(_ value: Cloud)

    @objc(removeCloudsObject:)
    @NSManaged public func removeFromClouds(_ value: Cloud)

    @objc(addClouds:)
    @NSManaged public func addToClouds(_ values: NSSet)

    @objc(removeClouds:)
    @NSManaged public func removeFromClouds(_ values: NSSet)

}

