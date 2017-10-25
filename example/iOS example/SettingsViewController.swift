//
//  SettingsViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData
import Stormcloud

class SettingsViewController: UIViewController, StormcloudViewController {

    var coreDataStack: CoreDataStack? {
        didSet {
            if let context = coreDataStack?.managedObjectContext {
                self.cloudAdder = CloudAdder(context: context)
            }
        }
    }

	var stormcloud: Stormcloud?
    var cloudAdder : CloudAdder?
    
    @IBOutlet var settingsSwitch1 : UISwitch!
    @IBOutlet var settingsSwitch2 : UISwitch!
    @IBOutlet var settingsSwitch3 : UISwitch!
    
    @IBOutlet var textField : UITextField!
    
    @IBOutlet var valueLabel : UILabel!
    @IBOutlet var valueStepper : UIStepper!

    @IBOutlet var cloudLabel : UILabel!
    
    func updateCount() {
        if let stack = coreDataStack {
            let clouds = stack.performRequestForTemplate(ICEFetchRequests.CloudFetch)
            self.cloudLabel.text = "Cloud Count: \(clouds.count)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		NotificationCenter.default.addObserver(self, selector: #selector(updateDefaults), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        
        self.prepareSettings()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateCount()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension SettingsViewController {
	@objc func updateDefaults(note : NSNotification ) {
		
		defer {
			self.prepareSettings()
		}
		
		guard let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
			return
		}
		
		if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
			guard let hasKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
				return
			}
			for key in hasKeys {
				let value = NSUbiquitousKeyValueStore.default.object(forKey: key)
				UserDefaults.standard.set(value, forKey: key)
			}
		}
    }
    
    func prepareSettings() {
        
        settingsSwitch1.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting1.rawValue)
        settingsSwitch2.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting2.rawValue)
        settingsSwitch3.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting3.rawValue)
        
        if let text = UserDefaults.standard.string(forKey: ICEDefaultsKeys.textValue.rawValue) {
            self.textField.text = text
        }
        
        self.valueStepper.value = Double(UserDefaults.standard.integer(forKey: ICEDefaultsKeys.stepperValue.rawValue))
        self.valueLabel.text = "Add Clouds: \(Int(valueStepper.value))"
    }
}

extension SettingsViewController {
    
    @IBAction func addNewClouds( _ sender : UIButton ) {
        if let adder = self.cloudAdder, let stack = self.coreDataStack {
            let clouds = stack.performRequestForTemplate(ICEFetchRequests.CloudFetch)
            let total = Int(self.valueStepper.value)
            let runningTotal = clouds.count + 1
            for i in 0 ..< total {
                adder.addCloudWithNumber(number: runningTotal + i, addRaindrops : false)
            }
            self.updateCount()
            
        }
    }
    
    @IBAction func settingsSwitchChanged( _ sender : UISwitch ) {
        
        var key : String?
        if let senderSwitch = sender.accessibilityLabel {
            if senderSwitch.contains("1") {
                key = ICEDefaultsKeys.Setting1.rawValue
            } else if senderSwitch.contains("2") {
                key = ICEDefaultsKeys.Setting2.rawValue
            } else if senderSwitch.contains("3") {
                key = ICEDefaultsKeys.Setting3.rawValue
            }
        }

        if let hasKey = key {
            UserDefaults.standard.set(sender.isOn, forKey: hasKey)
        }
        
    }
    
    @IBAction func stepperChanged( _ sender : UIStepper ) {
        self.valueLabel.text = "Add Clouds: \(Int(sender.value))"
        UserDefaults.standard.set(Int(sender.value), forKey: ICEDefaultsKeys.stepperValue.rawValue)
    }
    
    @IBAction func dismissCloudVC(_ sender : UIBarButtonItem ) {
        self.dismiss(animated: true, completion: nil)
    }
    
}


extension SettingsViewController : UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()        
        return true;
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        UserDefaults.standard.set(textField.text, forKey: ICEDefaultsKeys.textValue.rawValue)
    }
    
}
