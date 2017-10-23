//
//  StormcloudTableViewDataSource.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 22/10/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

open class StormcloudTableViewDataSource : NSObject, UITableViewDataSource {
	
	let dateFormatter = DateFormatter()
	let numberFormatter = NumberFormatter()

	let tableView : UITableView
	public let stormcloud : Stormcloud
	let cellIdentifier : String
	
	public init(tableView : UITableView, cellIdentifier : String, stormcloud : Stormcloud) {
		self.tableView = tableView
		self.stormcloud = stormcloud
		self.cellIdentifier = cellIdentifier
		super.init()
		stormcloud.delegate = self
	}
	
	open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "The JSON Documents"
		case 1:
			return "The Image Documents"
		default:
			return ""
		}
	}
	
	open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath as IndexPath)
		
		let metadata = data(at: indexPath)
		metadata.delegate = self
		
		self.configureTableViewCell(tvc: cell, withMetadata: metadata)
		
		
		return cell
	}
	
	func data(at indexPath : IndexPath ) -> StormcloudMetadata {
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

	func configureTableViewCell( tvc : UITableViewCell, withMetadata data: StormcloudMetadata ) {
		
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .short
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
		var text = dateFormatter.string(from: data.date)
		if let _ = data as? JPEGMetadata {
			text = "Image Backup"
		}
		
		data.delegate = self
		
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
	
	open func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

extension StormcloudTableViewDataSource : UITableViewDelegate {
	// Override to support editing the table view.
	open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			

			// If we don't have an item, nothing to delete
			let metadataItem = data(at: indexPath)
			stormcloud.deleteItem(metadataItem, completion: { ( index, error) -> () in
				if let _ = error {
					
				} 
			})
			
			// End
		} else if editingStyle == .insert {
			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
		}
	}
}

extension StormcloudTableViewDataSource : StormcloudDelegate  {
	
	public func stormcloudFileListDidLoad(_ stormcloud: Stormcloud) {

		
	}
	
	public func metadataDidUpdate(_ metadata: StormcloudMetadata, for type: StormcloudDocumentType) {
		
		let section : Int
		switch type {
		case .jpegImage:
			section = 1
		default:
			section = 0
		}
		
		if let index = stormcloud.items(for: type).index(of: metadata) {
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

extension StormcloudTableViewDataSource : StormcloudMetadataDelegate {
	open func iCloudMetadataDidUpdate(_ metadata: StormcloudMetadata) {
//		if let index = stormcloud.items(for: metadata.type).index(of: metadata) {
//			let ip = IndexPath(row: index, section: 0)
//			if let tvc = self.tableView.cellForRow(at: ip) {
//				self.configureTableViewCell(tvc: tvc, withMetadata: metadata)
//			}
//		}
	}

}
