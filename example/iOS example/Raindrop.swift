//
//  Raindrop.swift
//  iOS example
//
//  Created by Simon Fairbairn on 08/02/2020.
//  Copyright © 2020 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData
import UIKit

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
