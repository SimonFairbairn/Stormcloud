//
//  BackupDocument.swift
//  VTABM
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

open class JSONDocument: UIDocument, StormcloudDocument {

    open var backupMetadata : StormcloudMetadata?
    open var objectsToBackup : Any?
    
    open override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let data = contents as? Data {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : AnyObject]
                if let isJson = json {
                    self.objectsToBackup = isJson
                    self.backupMetadata = JSONMetadata(fileURL: self.fileURL)
                }
                
            } catch {
                print("Error reading JSON, or not correct format")
            }
        }
		
		updateChangeCount(.done)
    }
    
    open override func contents(forType typeName: String) throws -> Any {
        var data = Data()
        
        guard let hasData = self.objectsToBackup  else {
			throw StormcloudError.invalidJSON
        }
		do {
			data = try JSONSerialization.data(withJSONObject: hasData, options: .prettyPrinted)
			
		} catch {
			print("Error saving")
		}
		
		return NSData(data: data)
    }
	
	
}
