import Foundation
import UIKit

class DoseLogCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController: UINavigationController = LargeTitledNavigationController()
	var rootController: UIViewController { navigationController }
	private var dosageTableViewController: DosageTableViewController!

	let drugController: DrugController

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

extension DoseLogCoordinator: DosageTableViewControllerCoordinator {
	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, tappedDosage dosage: DoseEntry) {
		let dosageDetailVC = DosageDetailViewController.instantiate()
		dosageDetailVC.drugController = drugController
		dosageDetailVC.doseEntry = dosage
//		dosageDetailVC.delegate = self
		#warning("may need to resolve this")
		dosageDetailVC.modalPresentationStyle = .overFullScreen
		rootController.present(dosageDetailVC, animated: true)
	}
}
//extension DosageTableViewController: DosageDetailViewControllerDelegate {
//	// sometimes the frc doesn't trigger a refresh when an entry is updated, so this will do so when that happens
//	func dosageDetailVCDidFinish(_ dosageDetailVC: DosageDetailViewController) {
//		guard let indexPath = tableView.indexPathForSelectedRow else { return }
//		tableView.reloadRows(at: [indexPath], with: .automatic)
//	}
//}
