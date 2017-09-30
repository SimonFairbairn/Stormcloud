import UIKit
import Stormcloud
import CoreData

enum ICEDefaultsKeys : String {
    case Setting1 = "com.voyagetravelapps.iCloud-Extravaganza.Setting1PrefKey"
    case Setting2 = "com.voyagetravelapps.iCloud-Extravaganza.Setting2PrefKey"
    case Setting3 = "com.voyagetravelapps.iCloud-Extravaganza.Setting3PrefKey"
    case textValue = "com.voyagetravelapps.iCloud-Extravaganza.TextValuePrefKey"
    case stepperValue = "com.voyagetravelapps.iCloud-Extravaganza.StepperValuePrefKey"
    case iCloudToken = "nosync.com.voyagetravelapps.iCloud-Extravaganza.ubiquityToken"
}

enum ICEEnvironmentKeys : String, StormcloudEnvironmentVariable {
    case DeleteStore = "ICEDeleteStore"
    case DeleteAllItems = "ICEDeleteAllItems"
    case MoveDefaultItems = "ICEMoveDefaultItems"
    func stringValue() -> String {
        return self.rawValue
    }
}


//
//struct environment {
//    let deleteAllItems : Bool
//    init() {
//        let env = NSProcessInfo.processInfo().environment
//        if let _ = env["ICEDeleteAllItems"]  {
//            deleteAllItems = true
//        } else {
//            deleteAllItems = false
//        }
//    }
//}

enum ICEFetchRequests : String, CoreDataStackFetchTemplate {
    case CloudFetch = "CloudFetch"
    func fetchRequestName() -> String {
        return self.rawValue
    }
}

protocol StormcloudViewController {
	var stormcloud : Stormcloud? {
		get set
	}
	var coreDataStack : CoreDataStack? {
		get set
	}
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    let coreDataStack = CoreDataStack(modelName: "clouds")
	let stormcloud = Stormcloud()
	
    var window: UIWindow?
    
    var defaultsManager : StormcloudDefaultsManager = StormcloudDefaultsManager()
    
    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.defaultsManager.prefix = "com.voyagetravelapps.iCloud-Extravaganza"
        
        let adder = CloudAdder(context: nil)
        
        if ICEEnvironmentKeys.DeleteAllItems.isEnabled() {
            adder.deleteAllFiles()
        }
        if ICEEnvironmentKeys.MoveDefaultItems.isEnabled() {
            adder.copyDefaultFiles(name: "json")
        }
        if ICEEnvironmentKeys.DeleteStore.isEnabled() {
            coreDataStack.deleteStore()
        }
        
        coreDataStack.setupStore { () -> Void in
            if let context = self.coreDataStack.managedObjectContext {
                
                let adder = CloudAdder(context: context)
                
                if CoreDataStackEnvironmentVariables.UseMemoryStore.isEnabled() {
                    for i in 1..<1000 {
                        adder.addCloudWithNumber(number: i, addRaindrops : true)
                    }
                }
            }
		}
		
		if let isTabBar = window?.rootViewController as? UITabBarController {
			isTabBar.delegate = self
		}
        
        return true
    }
    
    
    
    
    func applicationWillResignActive(_: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.coreDataStack.save()
    }
    
    func applicationWillEnterForeground(_: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
}

extension AppDelegate : UITabBarControllerDelegate {
	
	func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
		
		guard let navController = viewController as? UINavigationController else {
			return true
		}
		
		if var stormcloudVC = navController.viewControllers.first as? StormcloudViewController {
			stormcloudVC.coreDataStack = coreDataStack
			stormcloudVC.stormcloud = stormcloud
		}
		
		if let cloudVC = navController.viewControllers.first as? StormcloudFetchedResultsController {
			
			if let context = coreDataStack.managedObjectContext, cloudVC.frc == nil {
				let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Cloud")
				fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
				fetchRequest.fetchBatchSize = 20
				cloudVC.frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
			}
			
			cloudVC.enableDelete = true
			cloudVC.cellCallback = { (tableView: UITableView, object: NSManagedObject, ip : IndexPath) -> UITableViewCell in
				guard let cell = tableView.dequeueReusableCell(withIdentifier: "CloudTableViewCell") else {
					return UITableViewCell()
				}
				if let cloudObject = object as? Cloud {
					cell.textLabel?.text =   cloudObject.name
					if let data = cloudObject.image as Data?,  let image = UIImage(data: data) {
						cell.imageView?.image = image
					}
				}
				return cell
			}
		}

		return true
	}
	
	
	func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
		
	}
}



