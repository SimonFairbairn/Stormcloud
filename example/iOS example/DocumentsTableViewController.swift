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
    var stormcloud: Stormcloud?
	var coreDataStack: CoreDataStack?
	
	var stormcloudTableView : StormcloudTableViewDataSource!
    let numberFormatter = NumberFormatter()
    
	
    
    @IBOutlet var iCloudSwitch : UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
		
		stormcloudTableView = StormcloudTableViewDataSource(tableView: self.tableView, cellIdentifier: "BackupTableViewCell", stormcloud: self.stormcloud!)

		tableView.delegate = stormcloudTableView
		tableView.dataSource = stormcloudTableView
		
        stormcloud?.reloadData()
        tableView.reloadData()
        // End
        
        self.iCloudSwitch.isOn = stormcloud?.isUsingiCloud ?? false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		self.tableView.reloadData()
		stormcloud?.deleteItems(.json, overLimit: 10, completion: { (error) in
			if let hasError = error {
				fatalError("Error deleting items over limit: \(hasError.localizedDescription)")
			}
		})
    }


    // MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return stormcloud?.items(for: .json).count ?? 0
		case 1:
			return stormcloud?.items(for: .jpegImage).count ?? 0
		default:
			return 0
		}
    }
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "JSON Documents"
		case 1:
			return "Image Documents"
		default:
			return ""
		}
	}

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
		
		if let hasItems = stormcloud?.items(for: type) {
			return hasItems[indexPath.row]
		}
		
		return nil
	}
	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BackupTableViewCell", for: indexPath as IndexPath)
		
        // MARK: - To Copy
		guard let data = data(at: indexPath) else {
			return cell
		}
        data.delegate = self
        // End
		
		self.configureTableViewCell(tvc: cell, withMetadata: data)

		
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
		
		guard let usingiCloud = stormcloud?.isUsingiCloud else {
			return
		}
		
		data.delegate = self
		
        if usingiCloud {
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


    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            // MARK: - To Copy
			
			// If we don't have an item, nothing to delete
			guard let metadataItem = data(at: indexPath) else {
				return
			}
            stormcloud?.deleteItem(metadataItem, completion: { ( index, error) -> () in
                
                if let _ = error {
                    
                    let alert = UIAlertController(title: "Couldn't delete item!", message: "Error", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) -> Void in
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            })

            // End
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
}

// MARK: - Methods

extension DocumentsTableViewController {

    func showAlertView(title : String, message : String ) {
        let alertViewController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        let action = UIAlertAction(title: "OK!", style: .cancel, handler: { (alertAction) -> Void in
            
        })
        alertViewController.addAction(action)
        self.present(alertViewController, animated: true, completion: nil)
    }
}

// MARK: - StormcloudDelegate

extension DocumentsTableViewController : StormcloudDelegate {
	func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
		
	}
	

	func metadataListDidAddItemsAtIndexes(_ addedItems: IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?) {
        
        self.tableView.beginUpdates()
        
        if let didAddItems = addedItems {
            var indexPaths : [IndexPath] = []
            for additionalItems in didAddItems {
                indexPaths.append(IndexPath(row: additionalItems, section: 0))
            }
            self.tableView.insertRows(at: indexPaths as [IndexPath], with: .automatic)
        }
        
        if let didDeleteItems = deletedItems {
            var indexPaths : [IndexPath] = []
            for deletedItems in didDeleteItems {
                indexPaths.append(IndexPath(row: deletedItems, section: 0))
            }
            self.tableView.deleteRows(at: indexPaths as [IndexPath], with: .automatic)
        }
        self.tableView.endUpdates()
    }
    
    
    func metadataListDidChange(_ manager: Stormcloud) {
//        self.configureDocuments()
    }
}


extension DocumentsTableViewController : StormcloudMetadataDelegate {
    func iCloudMetadataDidUpdate(_ metadata: StormcloudMetadata) {
        if let index = stormcloud?.items(for: metadata.type).index(of: metadata) {
			let ip = IndexPath(row: index, section: 0)
			if let tvc = self.tableView.cellForRow(at: ip) {
				self.configureTableViewCell(tvc: tvc, withMetadata: metadata)
            }
        }
    }
}

// End

// MARK: - Segue

extension DocumentsTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dvc = segue.destination as? DetailViewController, let tvc = self.tableView.indexPathForSelectedRow {
			
			if let metadata = data(at: tvc) {
				dvc.itemURL = stormcloud?.urlForItem(metadata)
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
            _ = stormcloud?.enableiCloudShouldMoveLocalDocumentsToiCloud(true) { (error) -> Void in
                
                if let hasError = error {
                    sender.isOn = false
                    if hasError == StormcloudError.iCloudUnavailable {
						self.showAlertView(title: "iCloud Unavailable", message: "Couldn't access iCloud. Are you logged in?")
                    }
                }

            }
        } else {
            stormcloud?.disableiCloudShouldMoveiCloudDocumentsToLocal(true, completion: { (moveSuccessful) -> Void in
                print("Disabled iCloud: \(moveSuccessful)")
            })
        }
    }
    
    @IBAction func doneButton(_  sender : UIBarButtonItem ) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func addButton( _ sender : UIBarButtonItem ) {
//        let jsonArray : AnyObject
//        if let jsonFileURL = NSBundle.mainBundle().URLForResource("questions_json", withExtension: "json"),
//            data = NSData(contentsOfURL: jsonFileURL) {
//
//            do {
//                
//                jsonArray = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
//            } catch let error as NSError {
//                print("Error reading json: \(error.localizedDescription)")
//                jsonArray = ["Error json" ]
//            }
//            
//        } else {
//            jsonArray = ["Error json" ]
//        }
//        let easyJSON : AnyObject
//        if let hasValue = NSUserDefaults.standardUserDefaults().objectForKey(ICEDefaultsKeys.textValue.rawValue) {
//            easyJSON = ["Item" : hasValue ]
//        } else {
//            easyJSON = ["Item" : "No Value"]
//        }

        if let context = coreDataStack?.privateContext {
            self.stormcloud?.backupCoreDataEntities(inContext: context, completion: { (error, metadata) -> () in

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
        
        
//        self.documentsManager.backupObjectsToJSON(jsonArray) { (success, metadata) -> () in
//            if let hasMetadata = metadata {
//
//            } else {
//                let alert = UIAlertController(title: "Couldn't add backup!", message: "Error", preferredStyle: .Alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: { (action) -> Void in
//                }))
//                
//                self.presentViewController(alert, animated: true, completion: nil)
//                
//            }
//        }
    }
}


