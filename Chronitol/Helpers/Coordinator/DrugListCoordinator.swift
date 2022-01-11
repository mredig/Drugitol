import Foundation
import UIKit

@MainActor
class DrugListCoordinator: NavigationCoordinator {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()
	var rootController: UIViewController { navigationController }
	private var drugEntryViewController: DrugEntryVC!

	let drugController: DrugController

	init(drugController: DrugController) {
		self.drugController = drugController
		self.drugEntryViewController = DrugEntryVC(coordinator: self, drugController: drugController)
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Drug List", image: UIImage(named: "capsule pills-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(drugEntryViewController, animated: false)
	}
}

extension DrugListCoordinator: DrugEntryVCCoordinator {
	func drugEntryVCTappedPlusButton(_ drugEntryVC: DrugEntryVC) {
		let newDrugVC = NewDrugViewController.instantiate()
		navigationController.pushViewController(newDrugVC, animated: true)
	}

	func drugEntryVC(_ drugEntryVC: DrugEntryVC, tappedDrug drug: DrugEntry) {
		let newDrugVC = NewDrugViewController.instantiate()
		newDrugVC.entry = drug

		navigationController.pushViewController(newDrugVC, animated: true)
	}
}
