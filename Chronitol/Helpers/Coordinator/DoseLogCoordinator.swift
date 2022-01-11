import Foundation
import UIKit

class DoseLogCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()
	var rootCoordinator: UIViewController { navigationController }
	private var dosageTableViewController: DosageTableViewController!

	init() {
		self.dosageTableViewController = DosageTableViewController.instantiate()
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Dosage Log", image: UIImage(named: "list-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(dosageTableViewController, animated: false)
	}
}
