import Foundation
import CoreData
import UIKit
import Logging

class DoseLogCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController: UINavigationController = LargeTitledNavigationController()
	var rootController: UIViewController { navigationController }
	private var dosageTableViewController: DosageTableViewController!

	let drugController: DrugController

	let log = Logger(label: "DoseLogCoordinator")

	init(drugController: DrugController) {
		self.drugController = drugController

		self.dosageTableViewController = DosageTableViewController(drugController: drugController, coordinator: self)
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Dosage Log", image: UIImage(named: "list-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(dosageTableViewController, animated: false)
	}
}

extension DoseLogCoordinator: DosageTableViewController.Coordinator {
	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, tappedDosage dosage: DoseEntry) {
		let dosageDetailVC = DosageDetailViewController.instantiate()
		dosageDetailVC.drugController = drugController
		dosageDetailVC.doseEntry = dosage
//		dosageDetailVC.delegate = self
		#warning("may need to resolve this")
		dosageDetailVC.modalPresentationStyle = .overFullScreen
		rootController.present(dosageDetailVC, animated: true)
	}

	func dosageTableViewController(
		_ dosageTableViewController: DosageTableViewController,
		tappedPendingDosage dosage: LocalNotifications.PendingDosageInfo
	) {
		print("tapped \(dosage.drugName)")
		switch dosage.dueTimestamp {
		case .due:
			Task {
				guard
					let idURL = dosage.drugID,
					let drugObjectID = ChronCoreDataStack
						.shared
						.mainContext
						.persistentStoreCoordinator?
						.managedObjectID(forURIRepresentation: idURL)
				else { return }

				await drugController.createDoseEntry(at: .now, forDrugWithID: drugObjectID)
				LocalNotifications.shared.resolveDeliveredNotification(withID: dosage.notificationID)
			}
		case .upcoming:
			break
		}
	}

	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, deletedPendingDosage dosage: LocalNotifications.PendingDosageInfo) {
		switch dosage.dueTimestamp {
		case .due:
			LocalNotifications.shared.resolveDeliveredNotification(withID: dosage.notificationID)
		case .upcoming(let dueDate):
			LocalNotifications.shared.deleteDrugAlarmNotification(withID: dosage.notificationID)
			do {
				try LocalNotifications.shared.createDelayedReminder(from: dosage, delayedUntilAfter: dueDate.addingTimeInterval(30))
			} catch {
				log.error("Error creating delayed reminder", metadata: ["error": .stringConvertible(error as CustomStringConvertible)])
			}
		}
	}

	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, deleteDosageEntryWithID dosageID: NSManagedObjectID) {
		guard
			let dose: DoseEntry = drugController.modelObject(for: dosageID)
		else { return }
		drugController.deleteDoseEntry(dose)
	}
}
