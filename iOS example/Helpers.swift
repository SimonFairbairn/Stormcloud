//
//  Helpers.swift
//  iOS example
//
//  Created by Simon Fairbairn on 25/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit

/// A conveninence class to use with UIKitDynamics and AutoLayout. Add this class to the dynamics simulation and use its properties to update the constraints in your view to have those views participate in the simulation.
public class DynamicHub: NSObject, UIDynamicItem {
    
    @objc public let bounds : CGRect
    @objc public var center : CGPoint = CGPointZero
    @objc public var transform : CGAffineTransform = CGAffineTransformIdentity
    
    public init(bounds : CGRect ) {
        self.bounds = bounds
        
    }
}


extension CGFloat {
    public func degreesToRads() -> CGFloat {
        let rads = self * CGFloat(M_PI / 180 )
        return rads
    }
    public func positionOnCircleInRect(rect : CGRect) -> CGPoint {
        let rads =  self.degreesToRads() - CGFloat( M_PI / 2)
        let x = rect.size.height / 2 * CGFloat(cos(rads))
        let y = rect.size.height / 2 * CGFloat(sin(rads))
        return CGPointMake(x + (rect.size.height / 2) + rect.origin.x, y + (rect.size.height / 2) + rect.origin.x)
    }
}
