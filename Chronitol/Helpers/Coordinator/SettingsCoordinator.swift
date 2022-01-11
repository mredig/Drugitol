import UIKit

class SettingsCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()

	var rootController: UIViewController { navigationController }
	private let settingsViewController: SettingsViewController

	init() {
		self.settingsViewController = SettingsViewController.instantiate(from: "Settings")
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Settings", image: UIImage(named: "setting-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(settingsViewController, animated: false)
	}
}
