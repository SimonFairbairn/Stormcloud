<img src="http://images.neverendingvoyage.com/github/StormcloudLogo.png" width="400" style="margin : 0 auto; display: block;" />

Stormcloud is an easy way to convert and write JSON to iCloud documents and back.

It also supports Core Data, converting a Core Data driven database to JSON and back—pass it an `NSManagedObjectContext` and it will read out all of the entities, attributes, and relationships, wrap them in a JSON document and upload that document to iCloud. 

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

Restoring 

```swift
stormcloud.restoreBackup(withMetadata metadata : StormcloudMetadata, completion : (error: StormcloudError?, restoredObjects : AnyObject? ) -> () ) {
    if let hasError = error {
        // Handle error
    } 
}
```

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
stormcloud.restoreCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext,  completion : (error : StormcloudError?) -> () ) {
    if let hasError = error {
        // Handle error here
    }
}
```

Installing using CocaoPods

To begin using pods see: https://cocoapods.org.
A minimal Podfile for Stormcloud could be:

```
target 'yourAppName'
use_frameworks!

pod 'Stormcloud'
```
