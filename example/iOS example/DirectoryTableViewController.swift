//
//  DirectoryTableViewController.swift
//  iOS example
//
//  Created by Simon Fairbairn on 22/10/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud

/// This View Controller is a convenience View Controller that reads the local/iCloud directories directly
/// allowing you to see what's happening underneath Stormcloud.
class DirectoryTableViewController: UITableViewController, StormcloudViewController {
	var coreDataStack: CoreDataStack?
	var stormcloud = Stormcloud()
	
	let numberFormatter = ByteCountFormatter()
	var fileContents = [URL]()
	
	var previous : URL?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Uncomment the following line to preserve selection between presentations
		// self.clearsSelectionOnViewWillAppear = false
		
		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
		// self.navigationItem.rightBarButtonItem = self.editButtonItem

		
		numberFormatter.countStyle = .file
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		let dir : URL
		if stormcloud.isUsingiCloud {
			self.title = "☁️ iCloud"
			dir = FileManager.default.url(forUbiquityContainerIdentifier: nil)!.appendingPathComponent("Documents")
		} else {
			self.title = "💾 Local"
			dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		}
		
		
		contents(for: dir)
	}
	
	deinit {
		print("Directory table view controller deinitialised")
	}
	
	func contents(for url : URL ) {
	
		do {
			fileContents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
		} catch {
			print("Error reading: \(url)")
			fileContents = []
		}
		
		tableView.reloadData()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// MARK: - Table view data source
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		return ( previous == nil ) ? fileContents.count : fileContents.count + 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "BrowserCell", for: indexPath)
		
		let url : URL
		var labelText  = ""
		if indexPath.row == fileContents.count {
			url = previous!
			labelText = "<- "
		} else {
			url = fileContents[indexPath.row]
		}
		if let atts = try? FileManager.default.attributesOfItem(atPath: url.path) {
			var text = ""
			if let hasType = atts[FileAttributeKey.type] as? String {
				text = "\(hasType)"
			}
			if let hasSize = atts[FileAttributeKey.size] as? NSNumber {
				text += " " + numberFormatter.string(fromByteCount: Int64(truncating: hasSize))
			}
			cell.detailTextLabel?.text = text
		}
		cell.textLabel?.text = labelText + url.lastPathComponent
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		
		let url : URL
		if indexPath.row == fileContents.count {
			url = previous!
			previous = url.deletingLastPathComponent()
		} else {
			url = fileContents[indexPath.row]
			previous = url.deletingLastPathComponent()
		}
		
		contents(for: url)
		
		tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
	}
	
	
	// Override to support conditional editing of the table view.
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		
		return indexPath.row < fileContents.count
	}
	
	
	// Override to support editing the table view.
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			// Delete the row from the data source
			let url = fileContents[indexPath.row]
			
			if let _ = try? FileManager.default.removeItem(at: url ) {
				fileContents.remove(at: indexPath.row)
				tableView.deleteRows(at: [indexPath], with: .fade)
			}
			
			
		} else if editingStyle == .insert {
			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
		}
	}
	
}
