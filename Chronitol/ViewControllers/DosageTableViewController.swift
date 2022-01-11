//
//  DosageTableViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/22/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit
import CoreData

@MainActor
class DosageTableViewController: UIViewController {

	let drugController: DrugController

	private var createNewDosageButton: UIBarButtonItem?
	private let tableView = UITableView()
	private let	drugSelectionCollection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

	private var drugSelectionDataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!

	private let headerStack = UIStackView().forAutolayout()

	lazy var dosageFetchedResultsController = drugController.createDosageFetchedResultsController(withDelegate: self)

	private static let sectionHeadFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		return formatter
	}()

	private var bag: Bag = []

	init(drugController: DrugController) {
		self.drugController = drugController
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = "Dosage Log"

		setupNewDosageButton()
		setupHeaderStack()
		setupHeaderStackDataSource()
		setupTableView()

		drugController
			.activeDrugPublisher
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: weakify { snap, strongSelf in
				strongSelf.drugSelectionDataSource.apply(snap, animatingDifferences: true)
				strongSelf.drugSelectionCollection.selectItem(at: IndexPath(item: DefaultsManager.lastSelectedDoseIndex, section: 0), animated: false, scrollPosition: .centeredHorizontally)
			})
			.store(in: &bag)
	}

	private func setupNewDosageButton() {
		let createNewDosageButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonPressed))
		self.createNewDosageButton = createNewDosageButton
		navigationItem.rightBarButtonItem = createNewDosageButton

		#if DEBUG
		let item = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(pending))
		navigationItem.rightBarButtonItems?.append(item)
		#endif
	}

	@objc func pending() {
		LocalNotifications.shared.pendInfo()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		updateViews()

		tableView.reloadData()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(tableView)

		var createFor: UIView.ConstraintEdgeToggle = true
		createFor.top = false
		constraints += view.constrain(subview: tableView, createConstraintsFor: createFor, activate: false)

		constraints += [
			tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor)
		]

		tableView.delegate = self
		tableView.dataSource = self

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DoseCell")
	}

	private func setupHeaderStack() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(headerStack)
		headerStack.axis = .vertical
		headerStack.alignment = .fill
		headerStack.distribution = .fill

		var createFor: UIView.ConstraintEdgeToggle = true
		createFor.bottom = false
		constraints += view.constrain(subview: headerStack, safeArea: true, createConstraintsFor: createFor, activate: false)

		let label = UILabel()
		label.text = "I just took a dose of..."
		label.font = .systemFont(ofSize: 17)
		label.textAlignment = .center
		headerStack.addArrangedSubview(label)
		headerStack.spacing = 16

		headerStack.addArrangedSubview(drugSelectionCollection)
		constraints += [
			drugSelectionCollection.heightAnchor.constraint(equalToConstant: 44)
		]

		let config = UICollectionViewCompositionalLayoutConfiguration()
		config.scrollDirection = .horizontal
		let size = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .fractionalHeight(1))
		let item = NSCollectionLayoutItem(layoutSize: size)
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitem: item, count: 1)
		let section = NSCollectionLayoutSection(group: group)
		section.interGroupSpacing = 8
		section.contentInsets = NSDirectionalEdgeInsets(horizontal: 20, vertical: 0)
		let layout = UICollectionViewCompositionalLayout(section: section, configuration: config)

		drugSelectionCollection.collectionViewLayout = layout
		drugSelectionCollection.showsHorizontalScrollIndicator = false
		drugSelectionCollection.delegate = self
	}

	private func setupHeaderStackDataSource() {
		let drugCellProvider = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID>(
			handler: weakify { cell, indexPath, objectID, strongSelf in
				var config = UIListContentConfiguration.cell()

				guard
					let drugID = strongSelf.drugSelectionDataSource.itemIdentifier(for: indexPath),
					let drug = strongSelf.drugController.drug(for: drugID)
				else { return }

				config.text = drug.name
				cell.contentConfiguration = config

				var bg = UIBackgroundConfiguration.listGroupedCell()
				bg.cornerRadius = 8
				cell.backgroundConfiguration = bg
			})

		drugSelectionDataSource = .init(collectionView: drugSelectionCollection, cellProvider: { collectionView, indexPath, itemIdentifier in
			collectionView.dequeueConfiguredReusableCell(using: drugCellProvider, for: indexPath, item: itemIdentifier)
		})
	}

	private func updateViews() {
		createNewDosageButton?.isEnabled = drugController.activeDrugIDs.hasContent
	}

	// MARK: - Actions
	@IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
		guard
			let currentSelection = drugSelectionCollection.indexPathsForSelectedItems?.first,
			let drugID = drugSelectionDataSource.itemIdentifier(for: currentSelection),
			let drug = drugController.drug(for: drugID)
		else { return }

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

extension DosageTableViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		DefaultsManager.lastSelectedDoseIndex = indexPath.item
	}
}
// MARK: - TableView stuff
extension DosageTableViewController: UITableViewDelegate, UITableViewDataSource {

	func numberOfSections(in tableView: UITableView) -> Int {
		dosageFetchedResultsController.sections?.count ?? 0
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dosageFetchedResultsController.sections?[section].numberOfObjects ?? 0
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let entry = dosageFetchedResultsController.object(at: indexPath)
			drugController.deleteDoseEntry(entry)
		}
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		showDosageDetail(for: dosageFetchedResultsController.object(at: indexPath))
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
	func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		drugController.activeDrugIDs.count
	}

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		let drugID = drugController.activeDrugIDs[row]
		guard let drug = drugController.drug(for: drugID) else { return nil }
		return drug.name
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
	}
}

extension DosageTableViewController: DosageDetailViewControllerDelegate {
	// sometimes the frc doesn't trigger a refresh when an entry is updated, so this will do so when that happens
	func dosageDetailVCDidFinish(_ dosageDetailVC: DosageDetailViewController) {
		guard let indexPath = tableView.indexPathForSelectedRow else { return }
		tableView.reloadRows(at: [indexPath], with: .automatic)
	}
}
