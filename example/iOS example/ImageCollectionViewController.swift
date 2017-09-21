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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes

        // Do any additional setup after loading the view.
		stormcloud.fileExtension = "jpg"
		stormcloud.delegate = self
		stormcloud.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stormcloud.metadataList.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
		let item = stormcloud.metadataList[indexPath.row]
		if let hasCell = cell as? ImageCollectionViewCell {
			if let url = stormcloud.urlForItem(item) {
				let doc = ImageDocument(fileURL: url)
				
				doc.open(completionHandler: { (success) in
					if ( success ) {
						hasCell.photoView.image = doc.imageToBackup
					}
				})
			}
			// Configure the cell
			hasCell.photoView.image = #imageLiteral(resourceName: "cloud")
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
		
		
		
	}
	
	
}
