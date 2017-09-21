//
//  DetailViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud


class DetailViewController: UIViewController {
    
    var itemURL : URL?
    var document : JSONDocument?
    var backupManager : Stormcloud?
    var stack  : CoreDataStack?
    
    @IBOutlet var detailLabel : UILabel!
    @IBOutlet var activityIndicator : UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let url = self.itemURL {
            self.document = JSONDocument(fileURL: url as URL)
            if let doc = self.document {
                doc.open(completionHandler: { (success) -> Void in
					
					DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        if let dict = doc.objectsToBackup as? [String : AnyObject] {
                            self.detailLabel.text = "Objects backed up: \(dict.count)"
                        }
                        
                    }
                })
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.document?.close(completionHandler: nil)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func restoreObject(_ sender : UIButton) {
        if let context = self.stack?.managedObjectContext, let doc = self.document {
            self.activityIndicator.startAnimating()
            self.view.isUserInteractionEnabled = false
            self.backupManager?.restoreCoreDataBackup(withDocument: doc, toContext: context , completion: { (error) -> () in
                self.activityIndicator.stopAnimating()
                self.view.isUserInteractionEnabled = true
            
                let message : String
                if let _ = error {
                    message = "With Errors"
                } else {
                    message = "Successfully"
                }
                
                let avc = UIAlertController(title: "Completed!", message: message, preferredStyle: .alert)
                avc.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(avc, animated: true, completion: nil)
            
            })
        }
    }
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}
