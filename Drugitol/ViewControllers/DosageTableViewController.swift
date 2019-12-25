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

	@IBOutlet private var drugPickerView: UIPickerView!
	lazy var dosageFetchedResultsController = drugController.createDosageFetchedResultsController(withDelegate: self)

	private static let sectionHeadFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		return formatter
	}()

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()

		drugPickerView.selectRow(DefaultsManager.lastSelectedDoseIndex, inComponent: 0, animated: true)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		drugPickerView.reloadAllComponents()
	}

	// MARK: - Actions
	@IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
		guard !drugController.activeDrugs.isEmpty else { return }
		let drug = drugController.activeDrugs[drugPickerView.selectedRow(inComponent: 0)]

		drugController.createDoseEntry(at: Date(), forDrug: drug)
	}

	func showDosageDetail(for doseEntry: DoseEntry) {
		guard let dosageDetailVC = storyboard?.instantiateViewController(withIdentifier: "DosageDetailViewController") as? DosageDetailViewController else { return }
		dosageDetailVC.drugController = drugController
		dosageDetailVC.doseEntry = doseEntry
		dosageDetailVC.delegate = self
		dosageDetailVC.modalPresentationStyle = .overFullScreen
		present(dosageDetailVC, animated: true)
	}
}

// MARK: - TableView stuff
extension DosageTableViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		dosageFetchedResultsController.sections?.count ?? 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "DoseCell", for: indexPath)

		let dosageEntry = dosageFetchedResultsController.object(at: indexPath)
		let drugEntry = dosageEntry.drug

		let drugName = drugEntry?.name ?? "A drug"
		let drugNameAttributed = NSMutableAttributedString(string: drugName, attributes: [.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)])

		let timeAttributed = NSAttributedString(string: ": \(dosageEntry.timeString)")
		drugNameAttributed.append(timeAttributed)
		cell.textLabel?.attributedText = drugNameAttributed
		return cell
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dosageFetchedResultsController.sections?[section].numberOfObjects ?? 0
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let entry = dosageFetchedResultsController.object(at: indexPath)
			drugController.deleteDoseEntry(entry)
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		showDosageDetail(for: dosageFetchedResultsController.object(at: indexPath))
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let doseEntry = dosageFetchedResultsController.object(at: IndexPath(row: 0, section: section))
		guard let date = doseEntry.date else { return nil }
		return DosageTableViewController.sectionHeadFormatter.string(from: date)
	}
}

// MARK: - FetchedResultsController Delegate
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
		nil
	}
}

extension DosageTableViewController: UIPickerViewDelegate, UIPickerViewDataSource {
	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		drugController.activeDrugs.count
	}

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		drugController.activeDrugs[row].name ?? "A drug"
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		DefaultsManager.lastSelectedDoseIndex = row
	}
}

extension DosageTableViewController: DosageDetailViewControllerDelegate {
	// sometimes the frc doesn't trigger a refresh when an entry is updated, so this will do so when that happens
	func dosageDetailVCDidFinish(_ dosageDetailVC: DosageDetailViewController) {
		guard let indexPath = tableView.indexPathForSelectedRow else { return }
		tableView.reloadRows(at: [indexPath], with: .automatic)
	}
}
