//: Playground - noun: a place where people can play

import UIKit
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

open class BackupDocument: UIDocument {
	
	open var objectsToBackup : Any?
	
	open override func load(fromContents contents: Any, ofType typeName: String?) throws {
		
		
		if let data = contents as? Data {
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : AnyObject]
				if let isJson = json {
					self.objectsToBackup = isJson
					
				}
				
			} catch {
				print("Error reading JSON, or not correct format")
			}
		}
	}
	
	open override func contents(forType typeName: String) throws -> Any {
		var data = Data()
		
		if let hasData = self.objectsToBackup {
			do {
				data = try JSONSerialization.data(withJSONObject: hasData, options: .prettyPrinted)
			} catch {
				print("Error writing JSON")
			}
			
		}
		
		return data
	}
}


let string = ["Doc" : "My Doc"]

let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.json")

let doc = BackupDocument(fileURL: url)
doc.objectsToBackup = string
doc.save(to: url, for: .forCreating) { (success) in
	print(success)
}





