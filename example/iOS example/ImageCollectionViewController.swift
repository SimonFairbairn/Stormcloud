//
//  ImageCollectionViewController.swift
//  iOS example
//
//  Created by Simon Fairbairn on 21/09/2017.
//  Copyright © 2017 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud

private let reuseIdentifier = "thumbnailCell"

class ImageCollectionViewController: UICollectionViewController  {
	
	var stormcloud: Stormcloud = Stormcloud()
	var coreDataStack: CoreDataStack?

	var imageCache : [String : UIImage] = [:]
	var count = 1
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes

        // Do any additional setup after loading the view.
		stormcloud.delegate = self
		stormcloud.reloadData()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return stormcloud.items(for: .jpegImage).count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
		let item = stormcloud.items(for: .jpegImage)[indexPath.row]
		if let hasCell = cell as? ImageCollectionViewCell {
			hasCell.photoView.image = #imageLiteral(resourceName: "cloud")
			
			if let hasImage = imageCache[item.filename] {
				hasCell.photoView.image = hasImage
			}  else {
				stormcloud.restoreBackup(withMetadata: item, completion: { (error, restoredObject) in
					if let hasImage = restoredObject as? UIImage {
						hasCell.photoView.image = hasImage
						self.imageCache[item.filename] = hasImage
					} else if let hasError = error  {
						print(hasError)
					}
				})
			}

		} else {
			cell.backgroundColor = .red
		}
    
		
        return cell
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}

extension ImageCollectionViewController : StormcloudDelegate {
	func metadataListDidAddItemsAt(_ addedItems: IndexSet?, andDeletedItemsAt deletedItems: IndexSet?, for type: StormcloudDocumentType) {
		
	}
	
	func metadataListDidChange(_ manager: Stormcloud) {
		collectionView?.reloadData()
	}
	func metadataListDidAddItemsAtIndexes(_ addedItems: IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?) {
		collectionView?.reloadData()
	}
}

extension ImageCollectionViewController {
	
	@IBAction func addImage( _ sender : UIBarButtonItem ) {
		// Get an image
		// Add it to stormcloud
		
		guard let image = UIImage(named: "Item\(count)") else {
			return
		}
		count = count + 1
		if count > 5 {
			count = 1
		}
		
		stormcloud.addDocument(withData: image, for: .jpegImage) { (error, metadata) in
			if let hasError = error {
				print("Error: \(hasError.localizedDescription)")
			}
		}
		
	}
	
	
}
