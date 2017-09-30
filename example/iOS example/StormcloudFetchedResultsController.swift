//
//  StormcloudFetchedResultsController.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/07/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

/**
*  The protocol to implement if you want the detail view controller to have access to an object selected by tapping a row.
*/
public protocol StormcloudFetchedResultsControllerDetailVC {
    func setManagedObject( object : NSManagedObject )
}

/**
This class has been designed to make subclassing entirely optional. You can set all the properties it needs on it directly. 

If your detail view controller conforms to the `VTAUtilitiesFetchedResultsControllerDetailVC` protocol, this class will pass along the selected object when a row is tapped.
*/
public class StormcloudFetchedResultsController: UITableViewController {

    /// A callback to be used in the table view delegate's `tableView:cellForRowAtIndexPath:` method. Passes along the managed object from the Fetched Results Controller
    public var cellCallback : ((_ tableView : UITableView, _ object : NSManagedObject, _ indexPath: IndexPath) -> UITableViewCell)?
    
    /// Whether to allow deletion of the rows
    public var enableDelete  = false
    
    /// The Fetched Results Controller to use.
    public var frc : NSFetchedResultsController<NSFetchRequestResult>? {
        didSet {
            self.frc?.delegate = self
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
		if enableDelete {
            self.navigationItem.rightBarButtonItem = self.editButtonItem
        }
    }
	
	public override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		guard let hasController = frc else {
			fatalError("Missing fetched results controller")
		}
		
		do {
			try hasController.performFetch()
		} catch {
			fatalError("Error performing fetch")
		}
		tableView.reloadData()
	}
	
	override public func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		frc = nil
	}
}

// MARK: - UITableViewDelegate

extension StormcloudFetchedResultsController {
    
    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return self.enableDelete
    }
    
    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete :
			if let frc = self.frc, let object = frc.object(at: indexPath) as? NSManagedObject {
                frc.managedObjectContext.delete(object)
            }
        case .insert, .none:
            break
        }
    }
    
}

// MARK: - UITableViewDataSource

extension StormcloudFetchedResultsController  {
    public override func numberOfSections(in tableView: UITableView) -> Int {
        return frc?.sections?.count ?? 1
    }
	
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sectionInfo = frc?.sections?[section] {
            return sectionInfo.numberOfObjects
        }
        return 0
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
		if let callback = self.cellCallback, let object = self.frc?.object(at: indexPath) as? NSManagedObject {
            return callback(tableView, object, indexPath)
        }
        return UITableViewCell()
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate

extension StormcloudFetchedResultsController : NSFetchedResultsControllerDelegate {
    
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    public func controller(controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            
        case .insert :
            tableView.insertSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .delete :
            tableView.deleteSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        default :
            break
        }
    }
    
    public func controller(_: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {


        
        switch type {
        case .insert :
            // get index path of didChangeObject
            //
            
            if let ip = newIndexPath {
                tableView.insertRows(at: [ip as IndexPath], with: .automatic)
            }
            break
        case .delete :
            if let ip = indexPath {
                tableView.deleteRows(at: [ip as IndexPath], with: .fade)
            }
        case .update :
            if let ip = indexPath {
                tableView.reloadRows(at: [ip as IndexPath], with: .automatic)
            }
        case .move :
            if let ip = indexPath, let newIP = newIndexPath {
                tableView.deleteRows(at: [newIP as IndexPath], with: .none)
                tableView.insertRows(at: [ip as IndexPath], with: .none)
                
            }
        }
        
    }
    
    public func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

// MARK: - Segue

extension StormcloudFetchedResultsController {
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var controller : UIViewController  = segue.destination
        if let possibleNav = segue.destination as? UINavigationController {
            controller = possibleNav.viewControllers.first ?? possibleNav
        }
        if let dvc = controller as? StormcloudFetchedResultsControllerDetailVC,
            let ip = self.tableView.indexPathForSelectedRow,
            let object = self.frc?.object(at: ip) as? NSManagedObject {
            dvc.setManagedObject(object: object)
        }
    }
    
}
