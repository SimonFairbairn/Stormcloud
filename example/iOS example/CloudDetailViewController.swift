//
//  CloudDetailViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 24/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud
import CoreData

class CloudDetailViewController: UIViewController {

    @IBOutlet weak var cloudImage : CloudView!
    @IBOutlet weak var raindropType: UISegmentedControl!
    @IBOutlet weak var cloudNameTextField: UITextField!
    @IBOutlet weak var exampleRaindrop: RaindropView!
    @IBOutlet weak var addRaindropButton : UIButton!
    
    @IBOutlet weak var raindropCount: UILabel!
    
    var currentCloud : Cloud?
    
    var dynamicAnimator : UIDynamicAnimator?
    let gravityBehaviour = UIGravityBehavior()
    
    var itemConstraints : [Int : [NSLayoutConstraint]] = [:]
    var dynamicItems : [Int : UIDynamicItem] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.raindropType.removeAllSegments()
        self.setupViews()
        
        self.dynamicAnimator = UIDynamicAnimator(referenceView: self.view)
        self.dynamicAnimator?.addBehavior(self.gravityBehaviour)
        
        self.addRaindropButton.isEnabled = false

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - Methods

extension CloudDetailViewController {
    func setupViews() {
        var count = 0
        for value in RaindropType.allValues {
            self.raindropType.insertSegment(withTitle: value.rawValue, at: count, animated: false)
            count += 1
        }
        
        self.cloudNameTextField.delegate = self
        
        guard let cloud = self.currentCloud else {
            return
        }
        
            if let didRain = cloud.didRain?.boolValue {
                self.cloudImage.cloudColor = didRain ? UIColor.lightGray : UIColor.darkGray
            }

        
        self.raindropCount.text = "\(cloud.raindrops!.count)"
        
        self.cloudNameTextField.text = cloud.name
        // Persist outstanding changes before edits
        self.saveChanges()
    }
    
    func saveChanges() {
        self.currentCloud?.name = self.cloudNameTextField.text
        do {
            try self.currentCloud?.managedObjectContext?.save()
        } catch {
            print("Error saving")
        }
    }
    
    func rollbackChanges() {
        self.currentCloud?.managedObjectContext?.rollback()
    }
    
    func colorFromSliders() -> UIColor {
        var r : CGFloat = 0
        var g : CGFloat = 0
        var b : CGFloat = 0
        if let rView =   self.view.viewWithTag(1) as? UISlider {
            r = CGFloat(rView.value)
        }
        if let gView =   self.view.viewWithTag(2) as? UISlider {
            g = CGFloat(gView.value)
        }
        if let bView =   self.view.viewWithTag(3) as? UISlider {
            b = CGFloat(bView.value)
        }
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
	@objc func addDynamicItem( item : UIDynamicItem ) {
        self.gravityBehaviour.addItem(item)
    }
}

extension CloudDetailViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}

// MARK: - Actions

extension CloudDetailViewController {
    
    @IBAction func selectedRaindropType( _ sender : UISegmentedControl ) {
        
        guard let cloud = self.currentCloud else {
            return
        }
        
        self.addRaindropButton.isEnabled = true
        
        let subviews = self.view.subviews.filter() { $0.tag >= 100 }
        
        for view in subviews {
            let index = view.tag - 100
            if let item = self.dynamicItems[index] {
                self.gravityBehaviour.removeItem(item)
            }
            view.removeFromSuperview()
        }
        
        let type = RaindropType.allValues[sender.selectedSegmentIndex]
        
        var size = CGRect.zero
        switch type {
        case .Drizzle:
			size = CGRect(x: 0, y: 0, width: 5, height: 9)
            self.gravityBehaviour.magnitude = 1.0
        case .Light:
            size = CGRect(x: 0, y: 0, width: 10, height: 18)
            self.gravityBehaviour.magnitude = 2.0
        case .Heavy :
            size = CGRect(x: 0, y: 0, width: 15, height: 27)
                        self.gravityBehaviour.magnitude = 3.0
        }
        
        let minLeading = CGFloat(self.cloudImage.frame.minX)
        let maxLeading = CGFloat(self.cloudImage.frame.maxX) - size.width
        let distance = maxLeading - minLeading
        
        func getRandomPosition() -> CGFloat {
            let randomPos = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
            return minLeading + (distance * randomPos)
        }
        
        
        var i = 0
        for raindrop in cloud.raindropsForType(type) {
            
            
            let raindropview = RaindropView(frame: size)
            raindropview.raindropColor = raindrop.colour as! UIColor
            raindropview.tag = 100 + i
            self.view.insertSubview(raindropview, belowSubview  : self.cloudImage)
            
            let yConstant : CGFloat = 30
            
            let xConstraint = NSLayoutConstraint(item: raindropview, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1.0, constant: getRandomPosition())
            let yConstraint = NSLayoutConstraint(item: raindropview, attribute: .centerY, relatedBy: .equal, toItem: self.cloudImage, attribute: .centerY, multiplier: 1.0, constant: yConstant)
            
            self.itemConstraints[raindropview.tag] = [xConstraint, yConstraint]
            
            raindropview.widthAnchor.constraint(equalToConstant: size.width).isActive = true
            raindropview.heightAnchor.constraint(equalToConstant: size.height).isActive = true

            self.view.addConstraint(xConstraint)
            self.view.addConstraint(yConstraint)
            
            let dynamicItem = DynamicHub(bounds : CGRect(x: 0, y: 0, width: size.width, height: size.height))
			dynamicItem.center = CGPoint(x: self.cloudImage.center.x, y: self.cloudImage.center.y + yConstant)
            
            self.dynamicItems[raindropview.tag] = dynamicItem

            let maxDelay : TimeInterval = 0.5
            let randomPos = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
            
			self.perform(#selector(self.addDynamicItem(item:)), with: dynamicItem, afterDelay: TimeInterval(maxDelay * TimeInterval(randomPos)) + TimeInterval(i) * 0.2)
            

            
            
            self.gravityBehaviour.action = {
                
                let subviews = self.view.subviews.filter() { $0.tag >= 100 }
                for subview in subviews {
                    if let dynamicItem = self.dynamicItems[subview.tag], let constraints = self.itemConstraints[subview.tag] , constraints.count == 2 {
                        
                        if subview.tag == 100 {
                            let view = self.view.viewWithTag(10)
                            view?.center = dynamicItem.center
                        }
                        
                        if constraints[1].constant > self.view.bounds.size.height {
                            self.gravityBehaviour.removeItem(dynamicItem)
                            constraints[1].constant = yConstant
                            subview.updateConstraintsIfNeeded()
                            constraints[0].constant = getRandomPosition()
                            
                        } else if constraints[1].constant == yConstant && dynamicItem.center.y > self.view.bounds.size.height {
                            dynamicItem.center = subview.center
                            self.gravityBehaviour.addItem(dynamicItem)
                        } else {
                            
                            constraints[1].constant = dynamicItem.center.y - self.cloudImage.frame.midY
                        }
                    }
                }
            }
            i += 1
        }
    }
    
    @IBAction func addRaindrop( _ sender : UIButton ) {
        
        guard let cloud = self.currentCloud else{
            return
        }
        
        do {
            let raindrop = try Raindrop.insertRaindropWithType(RaindropType.allValues[self.raindropType.selectedSegmentIndex], withCloud: cloud, inContext: cloud.managedObjectContext!)
            raindrop.colour = self.colorFromSliders()
            
            if let count = Int(raindropCount.text!) {
                self.raindropCount.text = "\(count + 1)"
            }
            

        } catch {
            print("Couldn't create raindrop")
        }
        
        self.selectedRaindropType( self.raindropType)
    }
    
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        self.exampleRaindrop.raindropColor  = self.colorFromSliders()

    }
    
    @IBAction func dismissVC(_ sender : UIBarButtonItem ) {
        self.rollbackChanges()
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func saveAndDismiss(_ sender : UIBarButtonItem ) {

        self.saveChanges()
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

// MARK: - VTAUtilitiesFetchedResultsControllerDetailVC

extension CloudDetailViewController : StormcloudFetchedResultsControllerDetailVC {
    
    func setManagedObject(object: NSManagedObject) {
        if let cloud = object as? Cloud {
            self.currentCloud = cloud
        }
    }
    
}

// MARK: - Segue

extension CloudDetailViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tagsVC = segue.destination as? TagsTableViewController {
            tagsVC.cloud = self.currentCloud
        }
    }
}

