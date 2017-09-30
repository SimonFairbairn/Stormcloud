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
	
	var metadataItem : StormcloudMetadata?
    var itemURL : URL?
    var document : JSONDocument?
    var backupManager : Stormcloud?
    var stack  : CoreDataStack?
    
    @IBOutlet var detailLabel : UILabel!
    @IBOutlet var activityIndicator : UIActivityIndicatorView!
	@IBOutlet var imageView: UIImageView!
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
		guard let hasMetadata = metadataItem else {
			return
		}
		self.imageView.isHidden = true
		self.detailLabel.isHidden = true
		
		switch hasMetadata {
		case is JSONMetadata:
			getObjectCount()
		case is JPEGMetadata:
			showImage()
		default:
			break
		}
    }
	
	func showImage() {
		guard let manager = backupManager, let jpegMetadata = metadataItem as? JPEGMetadata else {
			return
		}
		self.activityIndicator.startAnimating()
		
		manager.restoreBackup(withMetadata: jpegMetadata) { (error, image) in
			if let image = image as? UIImage {
				self.imageView.image = image
				self.imageView.isHidden = false
				self.activityIndicator.stopAnimating()
				self.activityIndicator.isHidden = true
			}
		}
	}
	
	func getObjectCount() {
		
		guard let manager = backupManager, let jsonMetadata = metadataItem as? JSONMetadata else {
			return
		}
		
		self.detailLabel.isHidden = false
		self.detailLabel.text = "Fetching object count..."
		self.activityIndicator.startAnimating()
		
		self.document = JSONDocument(fileURL: manager.urlForItem(jsonMetadata)! )
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.document?.close(completionHandler: nil)
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
