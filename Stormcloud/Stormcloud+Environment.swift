//
//  Stormcloud+Environment.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import Foundation


// A simple protocol with an implementation in an extension that will help us manage the environment
public protocol StormcloudEnvironmentVariable  {
	func stringValue() -> String
}

public extension StormcloudEnvironmentVariable {
	func isEnabled() -> Bool {
		let env = ProcessInfo.processInfo.environment
		if let _ = env[self.stringValue()]  {
			return true
		} else {
			return false
		}
	}
}

/**
A list of environment variables that you can use for debugging purposes.

Usage:

1. `Product -> Scheme -> Edit Scheme...`
2. Under `Environment variables` tap the `+` icon
3. Add `Stormcloud` + the enum case (e.g. `StormcloudMangleDelete`) as the name field. No value is required.

Valid variables:

- **`StormcloudMangleDelete`** : Mangles a delete so you can test your apps response to errors correctly
- **`StormcloudVerboseLogging`** : More verbose output to see what's happening within Stormcloud
*/
public enum StormcloudEnvironment : String, StormcloudEnvironmentVariable {
	case MangleDelete = "StormcloudMangleDelete"
	case VerboseLogging = "StormcloudVerboseLogging"
	public func stringValue() -> String {
		return self.rawValue
	}
}
