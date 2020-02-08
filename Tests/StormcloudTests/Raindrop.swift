//
//  Raindrop.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

public enum RaindropType : String {
    case Heavy, Light, Drizzle
    public static let allValues = [Heavy, Light, Drizzle]
}


public enum ICECoreDataError : Error {
    case invalidType
}

@objc(Raindrop)
open class Raindrop: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    
    open class func insertRaindropWithType(_ type : RaindropType, withCloud : Cloud, inContext context : NSManagedObjectContext ) throws -> Raindrop {
        
        if let drop1 = NSEntityDescription.insertNewObject(forEntityName: "Raindrop", into: context) as? Raindrop {
            drop1.type = type.rawValue
            drop1.cloud = withCloud
            drop1.colour = UIColor.red
            drop1.timesFallen = 10
            drop1.raindropValue = NSDecimalNumber(string: "10.54")
            return drop1
        } else {
            throw ICECoreDataError.invalidType
        }
    }
    
}

extension Raindrop {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Raindrop> {
        return NSFetchRequest<Raindrop>(entityName: "Raindrop")
    }

    @NSManaged public var colour: NSObject?
    @NSManaged public var raindropValue: NSDecimalNumber?
    @NSManaged public var timesFallen: NSNumber?
    @NSManaged public var type: String?
    @NSManaged public var cloud: Cloud?

}


