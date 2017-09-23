//
//  ImageMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit

class ImageMetadata : StormcloudMetadata {
	
	public override init() {
		super.init()
		self.date = Date()
		self.filename = UUID().uuidString + ".jpg"
	}
	public override init( path : String ) {
		super.init()
		self.filename = path
		self.date = Date()
	}
}