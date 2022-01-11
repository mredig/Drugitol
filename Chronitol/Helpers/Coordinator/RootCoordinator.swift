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
		children.append(doseLogCoordinator)
		doseLogCoordinator.start()

		let drugListCoordinator = DrugListCoordinator()
		children.append(drugListCoordinator)
		drugListCoordinator.start()

		let settingsCoordiantor = SettingsCoordinator()
		children.append(settingsCoordiantor)
		settingsCoordiantor.start()

		tabBarController.setViewControllers([
			doseLogCoordinator.rootController,
			drugListCoordinator.rootController,
			settingsCoordiantor.rootController,
		], animated: true)
	}
}