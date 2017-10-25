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
	
	let byteFormatter = ByteCountFormatter()
	var metadataItem : StormcloudMetadata?
    var itemURL : URL?
    var document : JSONDocument?
    var backupManager : Stormcloud?
    var stack  : CoreDataStack?
	
    @IBOutlet var detailLabel : UILabel!
	@IBOutlet var iCloudStatus : UILabel!
	@IBOutlet var iCloudProgress : UILabel!
    @IBOutlet var activityIndicator : UIActivityIndicatorView!
	@IBOutlet var imageView: UIImageView!
	@IBOutlet var progressView : UIProgressView!
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
		guard let hasMetadata = metadataItem else {
			return
		}
		self.imageView.isHidden = true
		self.detailLabel.isHidden = true
		metadataItem?.delegate = self
		updateLabel(with: hasMetadata)
		backupManager?.delegate = self
		backupManager?.coreDataDelegate = self
		self.title = ( hasMetadata.iniCloud ) ? "☁️" : "💾"
		
		switch hasMetadata {
		case is JSONMetadata:
			getObjectCount()
		case is JPEGMetadata:
			showImage()
		default:
			break
		}
    }
	
	func updateLabel( with metadata : StormcloudMetadata ) {
		
		var textItems : [String] = []
		var progress = ""
		
		if metadata.isUploading && metadata.percentUploaded < 100 {
			self.progressView.progress =  (Float(metadata.percentUploaded) / 100.0)
			progress = String(format: "%.2f", Float(metadata.percentUploaded)).appending("%")
			textItems.append("Uploading")
		}
		if metadata.iniCloud {
			self.progressView.progress = 1.0
			textItems.append("☁️")
		}
		
		if metadata.isDownloading && metadata.percentDownloaded < 100 {
			self.progressView.progress =  (Float(metadata.percentDownloaded) / 100.0)
			progress = String(format: "%.2f", Float(metadata.percentDownloaded)).appending("%")
			textItems.append("Downloading")
		}
		if metadata.isDownloaded {
			self.progressView.progress = 1.0
			textItems.append("💾")
		}
		
		self.iCloudStatus.text = textItems.joined(separator: " & ")
		self.iCloudProgress.text = progress
	}
	
	func updateLabel( with text : String ) {
		self.iCloudStatus.text = text
	}
	
	func showImage() {
		guard let manager = backupManager, let jpegMetadata = metadataItem as? JPEGMetadata else {
			return
		}

		self.activityIndicator.startAnimating()
		
		manager.restoreBackup(withMetadata: jpegMetadata) { (error, image) in
			DispatchQueue.main.async {
				self.activityIndicator.stopAnimating()
				self.activityIndicator.isHidden = true

				if let hasError = error {
					switch hasError {
					case .couldntOpenDocument:
						self.updateLabel(with: "Error with document. Possible internet.")
					default:
						self.updateLabel(with: "\(hasError.localizedDescription)")
					}
				} else {
					self.updateLabel(with: jpegMetadata)
					if let image = image as? UIImage {
						self.imageView.image = image
						self.imageView.isHidden = false
					}
				}
			}
		}
	}
	@IBAction func shareItem(_ sender: UIBarButtonItem ) {
		
		guard let item = metadataItem, let url = backupManager?.urlForItem(item	) else {
			return
		}
		
		let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
		vc.popoverPresentationController?.permittedArrowDirections = [.up, .down]
		vc.popoverPresentationController?.barButtonItem = sender
		
		present(vc, animated: true, completion: nil)
	}
	
	func getObjectCount() {
		
		guard let manager = backupManager, let jsonMetadata = metadataItem as? JSONMetadata else {
			return
		}
		
		self.detailLabel.isHidden = false
		self.detailLabel.text = "Fetching object count..."
		self.activityIndicator.startAnimating()
		
		self.document = JSONDocument(fileURL: manager.urlForItem(jsonMetadata)! )
		guard let doc = self.document else {
			updateLabel(with: "Error with document")
			return
		}
		doc.open(completionHandler: { (success) -> Void in
			DispatchQueue.main.async {
				DispatchQueue.main.async {
					self.updateLabel(with: jsonMetadata)
				}
				self.activityIndicator.stopAnimating()
				if let dict = doc.objectsToBackup as? [String : AnyObject] {
					let fs : String
					if let icloudData = jsonMetadata.iCloudMetadata, let size = icloudData.value(forAttribute: NSMetadataItemFSSizeKey) as? Int64 {
						fs = self.byteFormatter.string(fromByteCount: size)
					} else {
						fs = ""
					}
					
					self.detailLabel.text = "Objects backed up: \(dict.count). \(fs)"
				}
			}
		})

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
                if let hasError = error {
                    message = "With Errors"
					self.updateLabel(with: hasError.localizedDescription)
                } else {
                    message = "Successfully"
					self.iCloudProgress.text = ""
					self.updateLabel(with: "Successfully Restored")
                }
                
				self.presentAlert(with: message)
				
            })
        }
    }
	func presentAlert(with message : String ) {
		let avc = UIAlertController(title: "Completed!", message: message, preferredStyle: .alert)
		avc.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
		self.present(avc, animated: true, completion: nil)
	}
	
}

extension DetailViewController : StormcloudDelegate, StormcloudCoreDataDelegate {
	
	func stormcloudFileListDidLoad(_ stormcloud: Stormcloud) {

	}
	
	
	func metadataDidUpdate(_ metadata: StormcloudMetadata, for type: StormcloudDocumentType) {
		if metadata == self.metadataItem {
			updateLabel(with: metadata)
		}
	}
	func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
	
	}

	func metadataListDidChange(_ manager: Stormcloud) {
		
	}
	func metadataListDidAddItemsAtIndexes(_ addedItems: IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?) {
		
	}
	
	func stormcloud(_ stormcloud: Stormcloud, coreDataHit error: StormcloudError, for status: StormcloudCoreDataStatus) {
		updateLabel(with: "ERROR RESTORING")
	}
	func stormcloud(_ stormcloud: Stormcloud, didUpdate objectsUpdated: Int, of total: Int, for status: StormcloudCoreDataStatus) {
		self.progressView.progress =  (Float(objectsUpdated) / Float(total))
		self.iCloudProgress.text = String(format: "%.2f", (Float(objectsUpdated) / Float(total) ) * 100).appending("%")
		switch status {
		case .deletingOldObjects:
			updateLabel(with: "Deleting Old Objects")
		case .insertingNewObjects:
			updateLabel(with: "Inserting New Objects")
		case .establishingRelationships:
			updateLabel(with: "Establishing Relationships")
		}
	}
}

extension DetailViewController : StormcloudMetadataDelegate {
	func iCloudMetadataDidUpdate(_ metadata: StormcloudMetadata) {
		updateLabel(with: metadata)
	}
}
