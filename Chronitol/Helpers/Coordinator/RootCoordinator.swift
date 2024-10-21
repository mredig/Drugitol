import UIKit

class RootCoordinator: Coordinator {
	var children: [Coordinator] = []

	let window: UIWindow
	let tabBarController: UITabBarController

	let coreDataStack: ChronCoreDataStack
	let drugController: DrugController

	init(window: UIWindow, tabBarController: UITabBarController) {
		self.window = window
		self.tabBarController = tabBarController

		let coreDataStack = ChronCoreDataStack.shared
		self.coreDataStack = coreDataStack
		self.drugController = DrugController(coreDataStack: coreDataStack)
	}

	func start() {
		window.rootViewController = tabBarController
		window.makeKeyAndVisible()

		let doseLogCoordinator = DoseLogCoordinator(drugController: drugController)
		children.append(doseLogCoordinator)
		doseLogCoordinator.start()

		let drugListCoordinator = DrugListCoordinator(drugController: drugController)
		children.append(drugListCoordinator)
		drugListCoordinator.start()

		let settingsCoordiantor = SettingsCoordinator(drugController: drugController)
		children.append(settingsCoordiantor)
		settingsCoordiantor.start()

		tabBarController.setViewControllers([
			doseLogCoordinator.rootController,
			drugListCoordinator.rootController,
			settingsCoordiantor.rootController,
		], animated: true)
	}
}
