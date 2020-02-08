//
//  ImageDocument.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

open class ImageDocument: UIDocument, StormcloudDocument {
	
	open var backupMetadata : StormcloudMetadata?
	open var imageToBackup : UIImage?
	
	open override func load(fromContents contents: Any, ofType typeName: String?) throws {
		if let data = contents as? Data, let hasImage = UIImage(data: data) {
			self.imageToBackup = hasImage
			self.backupMetadata = JPEGMetadata(fileURL: self.fileURL)
		}
		
		updateChangeCount(.done)
	}
	
	open override func contents(forType typeName: String) throws -> Any {
		guard let isImage = self.imageToBackup, let hasData = isImage.jpegData(compressionQuality: 0.8)  else {
			throw StormcloudError.invalidDocumentData
		}
		return NSData(data: hasData)
	}
	
	
}
