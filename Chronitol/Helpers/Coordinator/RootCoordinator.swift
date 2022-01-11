import UIKit

class RootCoordinator: Coordinator {
	var children: [Coordinator] = []

	let window: UIWindow
	let tabBarController: UITabBarController

	let coreDataStack: CoreDataStack = CoreDataStack.shared

	init(window: UIWindow, tabBarController: UITabBarController) {
		self.window = window
		self.tabBarController = tabBarController
	}

	func start() {
		window.rootViewController = tabBarController
		window.makeKeyAndVisible()

		let doseLogCoordinator = DoseLogCoordinator()
		doseLogCoordinator.start()
		tabBarController.setViewControllers([doseLogCoordinator.rootCoordinator], animated: true)
	}
}
