//
//  DosageTableViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/22/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit
import CoreData

class DosageTableViewController: UITableViewController {

	let drugController = DrugController(context: .mainContext)

	lazy var fetchedResultsController = drugController.createDosageFetchedResultsController(withDelegate: self)

	@IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
		guard let drug = drugController.activeDrugs.first else { return }

		drugController.createDoseEntry(at: Date(), forDrug: drug)
	}
}

// MARK: - TableView stuff
extension DosageTableViewController {
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DoseCell", for: indexPath)

		let dosageEntry = fetchedResultsController.object(at: indexPath)
		let drugEntry = dosageEntry.drug

		let drugName = drugEntry?.name ?? "A drug"
		let drugNameAttributed = NSMutableAttributedString(string: drugName)
		let drugNameRange = NSRange(location: 0, length: drugNameAttributed.length)
		drugNameAttributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), range: drugNameRange)

		let timeAttributed = NSAttributedString(string: ": \(dosageEntry.timeString)")
		drugNameAttributed.append(timeAttributed)
		cell.textLabel?.attributedText = drugNameAttributed
		return cell
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let entry = fetchedResultsController.object(at: indexPath)
			drugController.deleteDoseEntry(entry)
		}
	}
}

extension DosageTableViewController: NSFetchedResultsControllerDelegate {
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
