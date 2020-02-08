//
//  ImageMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

open class JPEGMetadata : StormcloudMetadata {
	
	public override init() {
		super.init()
		self.date = Date()
		self.filename = UUID().uuidString + ".jpg"
		self.type = .jpegImage
	}
	public override init( path : String ) {
		super.init()
		self.filename = path
		self.date = Date()
		self.type = .jpegImage
	}
}


