//
//  StormcloudDefaultsManager.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit

open class StormcloudDefaultsManager: NSObject {
    
    open var prefix : String = ""
    var updatingiCloud = false
    
    override public init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(StormcloudDefaultsManager.ubiquitousContentDidChange(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(StormcloudDefaultsManager.enablediCloud(_:)), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(StormcloudDefaultsManager.userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    @objc func ubiquitousContentDidChange( _ note : Notification ) {
        
        for ( key, value ) in NSUbiquitousKeyValueStore.default.dictionaryRepresentation {
            if key.hasPrefix(self.prefix ) {
                if let isBool = value as? Bool {
                    UserDefaults.standard.set(isBool, forKey: key)
                }
                if let isInt = value as? Int {
                    UserDefaults.standard.set(isInt, forKey: key)
                }
                if let isString = value as? String {
                    UserDefaults.standard.set(isString, forKey: key)
                }
            }
        }
    }
    
    @objc func userDefaultsDidChange( _ note : Notification ) {
        if updatingiCloud {
            return
        }
        
        updatingiCloud = true
        
        for ( key, value ) in UserDefaults.standard.dictionaryRepresentation() {
            if key.hasPrefix(self.prefix ) {
                if let isBool = value as? Bool {
                    NSUbiquitousKeyValueStore.default.set(isBool, forKey: key)
                }
                if let isInt = value as? Int {
                    NSUbiquitousKeyValueStore.default.set(Int64(isInt), forKey: key)
                }
                if let isString = value as? String {
                    NSUbiquitousKeyValueStore.default.set(isString, forKey: key)
                }
            }
        }
        
        NSUbiquitousKeyValueStore.default.synchronize()
        
        updatingiCloud = false
    }
    
    
    @objc func enablediCloud( _ note : Notification? ) {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
