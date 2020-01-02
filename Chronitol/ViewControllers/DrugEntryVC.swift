//
//  ViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit
import CoreData

class DrugEntryVC: UIViewController {
	@IBOutlet private weak var tableView: UITableView!
	@IBOutlet private weak var createNewDrugButton: UIBarButtonItem!

	let drugController = DrugController(context: .mainContext)

	lazy var fetchedResultsController = drugController.createDrugFetchedResultsController(withDelegate: self)

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)

		if let destVC = segue.destination as? NewDrugViewController {
			if segue.identifier == "NewDrugSegue" {
			}

			if segue.identifier == "EditDrugSegue" {
				guard let indexPath = tableView.indexPathForSelectedRow else { return }
				destVC.entry = fetchedResultsController.object(at: indexPath)
			}
		}
	}
}

extension DrugEntryVC: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DrugEntryCell", for: indexPath)

		let drug = fetchedResultsController.object(at: indexPath)
		let alarms = drug.alarms?.compactMap { $0 as? DrugAlarm } ?? []
		cell.textLabel?.text = drug.name
		cell.detailTextLabel?.text = alarms.map { $0.prettyTimeString }.joined(separator: ", ")

		return cell
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else { return }
		let entry = fetchedResultsController.object(at: indexPath)
		drugController.deleteDrugEntry(entry)
	}
}

// MARK: - Fetched Results Controller Delegate
extension DrugEntryVC: NSFetchedResultsControllerDelegate {
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		tableView.beginUpdates()
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		tableView.endUpdates()
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
					didChange sectionInfo: NSFetchedResultsSectionInfo,
					atSectionIndex sectionIndex: Int,
					for type: NSFetchedResultsChangeType) {
		let indexSet = IndexSet([sectionIndex])
		switch type {
		case .insert:
			tableView.insertSections(indexSet, with: .automatic)
		case .delete:
			tableView.deleteSections(indexSet, with: .automatic)
		default:
			print(#line, #file, "unexpected NSFetchedResultsChangeType: \(type)")
		}
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
					didChange anObject: Any,
					at indexPath: IndexPath?,
					for type: NSFetchedResultsChangeType,
					newIndexPath: IndexPath?) {
		switch type {
		case .insert:
			guard let newIndexPath = newIndexPath else { return }
			tableView.insertRows(at: [newIndexPath], with: .automatic)
		case .move:
			guard let newIndexPath = newIndexPath, let indexPath = indexPath else { return }
			tableView.moveRow(at: indexPath, to: newIndexPath)
		case .update:
			guard let indexPath = indexPath else { return }
			tableView.reloadRows(at: [indexPath], with: .automatic)
		case .delete:
			guard let indexPath = indexPath else { return }
			tableView.deleteRows(at: [indexPath], with: .automatic)
		@unknown default:
			print(#line, #file, "unknown NSFetchedResultsChangeType: \(type)")
		}
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, sectionIndexTitleForSectionName sectionName: String) -> String? {
		return nil
	}
}
