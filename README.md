<img src="http://images.neverendingvoyage.com/github/StormcloudLogo.png" width="400" style="margin : 0 auto; display: block;" />

Stormcloud is a way to convert and write JSON files and JPEG images to iCloud documents and back.

It also supports Core Data, converting a Core Data driven database to JSON and back—pass it an `NSManagedObjectContext` and it will read out all of the entities, attributes, and relationships, wrap them in a JSON document and upload that document to iCloud, where it can be restored on another device.

## Usage

```swift
let stormcloud = Stormcloud()
```

Regular JSON:


```swift
stormcloud.backupObjectsToJSON( objects : AnyObject, completion : (error : StormcloudError?, metadata : StormcloudMetadata?) -> () ) {

    if let hasError = error {
        // Handle error
    } 

    if let newMetadata = metadata {
        print("Successfully added new document with filename: \(metadata.filename)")
    }
})

```

Image:

```swift

let image = UIImage(named: "YourImage")
stormcloud.addDocument( withData: image, for: .jpegImage ) { (error, stormcloudMetadata) in

	if let hasError = error {
		// Error creating document
	} else {
		print("Successfully added new document with filename: \(stormcloudMetadata!.filename)")
	}
}

```

Restoring 

```swift
stormcloud.restoreBackup(withMetadata: metadataItem ) { (error, restoredObjects ) in
    if let hasError = error {
        // Handle error
	} else if let isImage = restoredObjects as? UIImage {
		// Do something with the image
	} else if let isJSON = restoredObjects as? [String : Any] {
		// Do something with the JSON
	}
}
```

### Core Data

Managed Object Context:


```swift
stormcloud.backupCoreDataEntities(inContext: self.managedObjectContext, completion: { (error, metadata) -> () in

    if let hasError = error {
        // Handle error
    } 

    if let newMetadata = metadata {
        print("Successfully added new document with filename: \(metadata.filename)")
    }

})

```

Restoring 

```swift
stormcloud.restoreCoreDataBackup(with : stormCloudMetadata, to context : NSManagedObjectContext,  completion : (error : StormcloudError?) -> () ) {
    if let hasError = error {
        // Handle error here
    }
}
```

### Getting Items

```swift

let jsonItems = stormcloud.items(for: .json)		// Returns an array of metadata items
let images = stormcloud.items(for: .jpegImage) 	// Returns an array of metadata items

```

## Metadata

Stormcloud has its own metadata object that is used for both iCloud and local documents. If you're using iCloud, the metadata property `iCloudMetadata` will be set. The objects also have convenience properties detailing their current status (where they are (iCloud or local), whether they're uploading or downloading, etc).

## Delegate

Stormcloud has a range of delegate methods.

```swift
// Called when a metadata item is updated in any way. Useful for getting downloading/uploading progress of items.
func metadataDidUpdate(metadata : StormcloudMetadata,type : StormcloudDocumentType) {

}

// Called when the internal list changes
func metadataListDidChange(manager : Stormcloud) {

}

// Called when items are added or deleted from the interal list. Here's an example of how this can be used with a table view with appropriate animations:
func metadataListDidAddItemsAt( addedItems : IndexSet?, deletedItems: IndexSet?, type : StormcloudDocumentType) {
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

// Called when the file list first finishes loading. If you're using iCloud, the list will not be ready until the first
// gathering of documents has completed. This method allows you to know when the list is ready to be used.
func stormcloudFileListDidLoad( stormcloud : Stormcloud) {

}
```

## Installation

Installing using CocaoPods

To begin using pods see: https://cocoapods.org.
A minimal Podfile for Stormcloud could be:

```
target 'yourAppName'
use_frameworks!

pod 'Stormcloud'
```


## Environment Variables

Stormcloud supports environment variables for extra debugging and logging.

Environment variables:

`StormcloudDelayLocalFiles` - When set, the Local Files document provider will delay its initial gathering of the files. Allows you to simulate how iCloud's metadata gathering works without enabling iCloud.

`StormcloudVerboseLogging` - Enables comprehensive logging for debugging.

