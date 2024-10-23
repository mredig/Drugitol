import UIKit
import SwiftPizzaSnips
import Logging

class RootCoordinator: Coordinator {
	var children: [Coordinator] = []

	let window: UIWindow
	let tabBarController: UITabBarController

	let coreDataStack: ChronCoreDataStack
	let drugController: DrugController

	let log = Logger(label: "RootCoordinator")

	init(window: UIWindow, tabBarController: UITabBarController) {
		self.window = window
		self.tabBarController = tabBarController

		let coreDataStack = ChronCoreDataStack.shared
		self.coreDataStack = coreDataStack
		self.drugController = DrugController(coreDataStack: coreDataStack)

		LocalNotifications.shared.delegate = drugController
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

		Task {
			await setupTaskManager()
		}
	}

	private func setupTaskManager() async {
		await TaskManager.addTask(59) { [weak self] in
			let delayedAlarms = DefaultsManager.shared[.delayedAlarms]
			guard let self else { return }

			for alarm in delayedAlarms {
				guard alarm.scheduleAfter < .now else { continue }

				defer { DefaultsManager.shared[.delayedAlarms].removeAll(where: { $0 == alarm }) }
				do {
					guard
						let objectID = self.coreDataStack.container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: alarm.alarmIDURL)
					else { continue }
					try await LocalNotifications.shared.createDrugReminder(forDrugAlarmWithID: objectID, using: self.drugController)
				} catch {
					log.error("Error creating delayed drug reminder", metadata: ["error": .stringConvertible(error as CustomStringConvertible)])
				}
			}
		}

		await TaskManager.start()
	}
}
