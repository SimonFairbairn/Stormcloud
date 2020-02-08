//
//  DocumentsTableViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud

class DocumentsTableViewController: UITableViewController, StormcloudViewController {
	
    let dateFormatter = DateFormatter()
    var stormcloud: Stormcloud  = Stormcloud()
	var coreDataStack: CoreDataStack?
	
    let numberFormatter = NumberFormatter()
    
    @IBOutlet var iCloudSwitch : UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

		
        self.iCloudSwitch.isOn = stormcloud.isUsingiCloud
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		stormcloud.delegate = self
		tableView.reloadData()
		if stormcloud.fileListLoaded {
			deleteOldValues()
		}
	}
	
	func deleteOldValues() {
		stormcloud.deleteItems(.json, overLimit: 3) { (error) in
			if let hasError = error {
				self.showAlertView(title: "Error Deleting", message: hasError.localizedDescription)
			} else {
				self.showAlertView(title: "Update!", message: "Items over limit deleted")
			}
		}
	}
}

// MARK: - Methods

extension DocumentsTableViewController {

    func showAlertView(title : String, message : String ) {
        let alertViewController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        let action = UIAlertAction(title: "OK!", style: .cancel, handler: { (alertAction) -> Void in
            
        })
        alertViewController.addAction(action)
        self.present(alertViewController, animated: true, completion: nil)
    }
}

// MARK: - StormcloudDelegate

extension DocumentsTableViewController  {

	func data(at indexPath : IndexPath ) -> StormcloudMetadata? {
		let type : StormcloudDocumentType
		switch indexPath.section {
		case 0:
			type = .json
		case 1:
			type = .jpegImage
		default:
			type = .unknown
		}
		
		return stormcloud.items(for: type)[indexPath.row]
	}
}



// MARK: - Segue

extension DocumentsTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dvc = segue.destination as? DetailViewController, let tvc = self.tableView.indexPathForSelectedRow {
			
			if let metadata = self.data(at: tvc) {
				dvc.itemURL = stormcloud.urlForItem(metadata)
				dvc.metadataItem = metadata
			}
			
            dvc.backupManager = stormcloud
            dvc.stack  = coreDataStack
        }
    }
}

// MARK: - Actions

extension DocumentsTableViewController {
    
    @IBAction func enableiCloud( _ sender : UISwitch ) {
        if sender.isOn {
			
			stormcloud.enableiCloudShouldMoveDocuments(true, completion: { (error) in
				if let hasError = error {
					sender.isOn = false
					if hasError == StormcloudError.iCloudUnavailable {
						self.showAlertView(title: "iCloud Unavailable", message: "Couldn't access iCloud. Are you logged in?")
					} else {
						self.showAlertView(title: "Other Error", message: "\(hasError.localizedDescription)")
					}

				}
			})
			
////            _ = stormcloud?.enableiCloudShouldMoveLocalDocumentsToiCloud(true) { (error) -> Void in
//                
//                if let hasError = error {
//                }
//
//            }
        } else {
            stormcloud.disableiCloudShouldMoveiCloudDocumentsToLocal(true, completion: { (moveSuccessful) -> Void in
                print("Disabled iCloud: \(moveSuccessful)")
            })
        }
    }
    
    @IBAction func doneButton(_  sender : UIBarButtonItem ) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func addButton( _ sender : UIBarButtonItem ) {
        if let context = coreDataStack?.privateContext {
            self.stormcloud.backupCoreDataEntities(in: context, completion: { (error, metadata) -> () in

                var title = NSLocalizedString("Success!", comment: "The title of the alert box shown when a backup successfully completes")
                var message = NSLocalizedString("Successfully backed up all Core Data entities.", comment: "The message when the backup manager successfully completes")
                
                if let hasError = error {
                    title = NSLocalizedString("Error!", comment: "The title of the alert box shown when there's an error")
                    
                    switch hasError {
                    case .invalidJSON:
                        message = NSLocalizedString("There was an error creating the backup document", comment: "Shown when a backup document couldn't be created")
                    case .backupFileExists:
                        message = NSLocalizedString("The backup filename already exists. Please wait a second and try again.", comment: "Shown when the file already exists on disk.")
                    case .couldntMoveDocumentToiCloud:
                        message = NSLocalizedString("Saved backup locally but couldn't move it to iCloud. Is your iCloud storage full?", comment: "Shown when the file could not be moved to iCloud.")
                    case .couldntSaveManagedObjectContext:
                        message = NSLocalizedString("Error reading from database.", comment: "Shown when the database context could not be read.")
                    case .couldntSaveNewDocument:
                        message = NSLocalizedString("Could not create a new document.", comment: "Shown when a new document could not be created..")
                    case .invalidURL:
                        message = NSLocalizedString("Could not get a valid URL.", comment: "Shown when it couldn't get a URL either locally or in iCloud.")
                    default:
                        break

                    }
                }
                
                if let _ = self.presentedViewController as? UIAlertController {
                    self.dismiss(animated: false, completion: nil)
                }

                self.showAlertView(title: title, message: message)
                
                
            })
            self.coreDataStack?.save()
        }
	
    }

}

extension DocumentsTableViewController {
	open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "JSON Documents"
		case 1:
			return "Image Documents"
		default:
			return ""
		}
	}
	
	open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "BackupTableViewCell", for: indexPath as IndexPath)
		
		guard let metadata = data(at: indexPath) else {
			return cell
		}
		self.configureTableViewCell(tvc: cell, withMetadata: metadata)
		return cell
	}
	
	func configureTableViewCell( tvc : UITableViewCell, withMetadata data: StormcloudMetadata ) {
		
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .short
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
		var text = dateFormatter.string(from: data.date)
		if let _ = data as? JPEGMetadata {
			text = "Image Backup"
		}
		
//		data.delegate = self

		if stormcloud.isUsingiCloud {
			if data.iniCloud {
				text.append(" ☁️")
			}
			if data.isDownloaded {
				text.append(" 💾")
			}
			if data.isDownloading {
				text.append(" ⏬ \(self.numberFormatter.string(from: NSNumber(value: data.percentDownloaded / 100)) ?? "0")")
			} else if data.isUploading {
				
				self.numberFormatter.numberStyle = NumberFormatter.Style.percent
				text.append(" ⏫ \(self.numberFormatter.string(from: NSNumber(value: data.percentUploaded / 100 ))!)")
			}
		}
		
		tvc.textLabel?.text = text
		if let isJPEG = data as? JPEGMetadata {
			tvc.detailTextLabel?.text = "Filename: \(isJPEG.filename)"
		} else if let isJson = data as? JSONMetadata {
			tvc.detailTextLabel?.text = ( isJson.device == UIDevice.current.name ) ? "This Device" : isJson.device
		}
		
	}
	
	open override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return stormcloud.items(for: .json).count
		case 1:
			return stormcloud.items(for: .jpegImage).count
		default:
			return 0
		}
	}

}

extension DocumentsTableViewController  {
	// Override to support editing the table view.
	open override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			
			// If we don't have an item, nothing to delete
			guard let metadataItem = data(at: indexPath) else {
				return
			}
			stormcloud.deleteItem(metadataItem, completion: { ( index, error) -> () in
				if let hasError = error {
					self.showAlertView(title: "Error Deleting", message: hasError.localizedDescription)
				}
			})
			
			// End
		} else if editingStyle == .insert {
			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
		}
	}
}

extension DocumentsTableViewController : StormcloudDelegate  {
	
	public func stormcloudFileListDidLoad(_ stormcloud: Stormcloud) {
		deleteOldValues()
		self.tableView.reloadData()
	}
	
	public func metadataDidUpdate(_ metadata: StormcloudMetadata, for type: StormcloudDocumentType) {
		
		let section : Int
		switch type {
		case .jpegImage:
			section = 1
		default:
			section = 0
		}
		
		if let index = stormcloud.items(for: type).firstIndex(of: metadata) {
			let ip = IndexPath(row: index, section: section)
			if let tvc = self.tableView.cellForRow(at: ip) {
				self.configureTableViewCell(tvc: tvc, withMetadata: metadata)
			}
		}
		
	}
	public func metadataListDidChange(_ manager: Stormcloud) {
		
	}
	
	public func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
		self.tableView.beginUpdates()
		
		var section : Int
		switch type {
		case .jpegImage:
			section = 1
		default:
			section = 0
		}
		
		if let didAddItems = addedItems {
			var indexPaths : [IndexPath] = []
			for additionalItems in didAddItems {
				indexPaths.append(IndexPath(row: additionalItems, section: section))
			}
			self.tableView.insertRows(at: indexPaths as [IndexPath], with: .automatic)
		}
		
		if let didDeleteItems = deletedItems {
			var indexPaths : [IndexPath] = []
			for deletedItems in didDeleteItems {
				indexPaths.append(IndexPath(row: deletedItems, section: section))
			}
			self.tableView.deleteRows(at: indexPaths as [IndexPath], with: .automatic)
		}
		self.tableView.endUpdates()
		
	}
	
	
}


