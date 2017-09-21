
//
//  CloudAdder.swift
//  iOS example
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData

class CloudAdder : NSObject {
	let context : NSManagedObjectContext?
	
	let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
	
	init(context : NSManagedObjectContext? ) {
		self.context = context
	}
	
	
	func addCloudWithNumber(number : Int, addRaindrops : Bool ) {
		guard let context = self.context else {
			fatalError("Context not set")
		}
		
		
		let cloud1 : Cloud
		do {
			cloud1 = try Cloud.insertCloudWithName("Cloud \(number)", order: number, didRain: false, inContext: context)
			if addRaindrops {
				_ = try? Raindrop.insertRaindropWithType(RaindropType.Heavy, withCloud: cloud1, inContext: context)
				_ = try? Raindrop.insertRaindropWithType(RaindropType.Heavy, withCloud: cloud1, inContext: context)
				_ = try? Raindrop.insertRaindropWithType(RaindropType.Light, withCloud: cloud1, inContext: context)
			}
			
		} catch {
			print("Error inserting cloud!")
		}
	}
	
	
	
	func addDefaultClouds() {
		guard let context = self.context else {
			return
		}
		
		
		let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Cloud")
		let clouds : [Cloud]
		do {
			clouds = try context.fetch(request) as! [Cloud]
		} catch {
			clouds = []
		}
		
		print(clouds.count)
		
		self.addCloudWithNumber(number: clouds.count, addRaindrops : true)
		self.addCloudWithNumber(number: clouds.count + 1, addRaindrops : true)
	}
	
	func deleteAllFiles() {
		let docs = self.listItemsAtURL()
		for url in docs {
			if url.pathExtension == "json" {
				do {
					try FileManager.default.removeItem(at: url as URL)
				} catch {
					print("Couldn't delete item")
				}
			}
		}
		
	}
	
	func listItemsAtURL() -> [URL] {
		var jsonDocs : [URL] = []
		if let docsURL = docsURL {
			var docs : [URL] = []
			do {
				print(docsURL)
				docs = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
			} catch let error as NSError {
				print("\(docsURL) path not available.\(error.localizedDescription)")
			}
			
			for url in docs {
				if url.pathExtension == "json" {
					jsonDocs.append(url)
				}
			}
		}
		return jsonDocs
	}
	
	
	
	func copyDefaultFiles(name : String ) {
		if let fileURLs = Bundle.main.urls(forResourcesWithExtension: ".json", subdirectory: nil), let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
			print(docsURL)
			for url in fileURLs {
				let finalURL = docsURL.appendingPathComponent(url.lastPathComponent)
				
				do {
					try FileManager.default.copyItem(at: url, to: finalURL)
				} catch let error as NSError {
					print("Couldn't copy files \(error.localizedDescription)")
				}
				
			}
		}
	}
}
