import Foundation
import UIKit

class DrugListCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()
	var rootController: UIViewController { navigationController }
	private var drugEntryViewController: DrugEntryVC!

	init() {
		self.drugEntryViewController = DrugEntryVC.instantiate()
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Drug List", image: UIImage(named: "capsule pills-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(drugEntryViewController, animated: false)
	}
}
