import UIKit
import CoreData

@MainActor
protocol DosageTableViewControllerCoordinator: Coordinator {
	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, tappedDosage dosage: DoseEntry)
}

@MainActor
class DosageTableViewController: UIViewController {

	let drugController: DrugController

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

	private unowned let coordinator: DosageTableViewControllerCoordinator

	init(drugController: DrugController, coordinator: DosageTableViewControllerCoordinator) {
		self.drugController = drugController
		self.coordinator = coordinator
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = "Dosage Log"

		setupDebugButton()
		setupTableView()
		setupHeaderStack()
		setupHeaderStackDataSource()

		drugController
			.activeDrugPublisher
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: weakify { snap, strongSelf in
				strongSelf.drugSelectionDataSource.apply(snap, animatingDifferences: true)
			})
			.store(in: &bag)
	}

	private func setupDebugButton() {
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

		tableView.reloadData()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(tableView)

		var createFor: UIView.ConstraintEdgeToggle = true
		createFor.top = false
		constraints += view.constrain(subview: tableView, createConstraintsFor: createFor, activate: false)

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
		let insets = NSDirectionalEdgeInsets(horizontal: 0, vertical: 8)
		constraints += view.constrain(
			subview: headerStack,
			directionalInset: insets,
			safeArea: true,
			createConstraintsFor: createFor,
			activate: false)

		let label = UILabel()
		label.text = "I just took a dose of..."
		label.font = .italicSystemFont(ofSize: 14)

		let labelContainer = UIView().forAutolayout()
		labelContainer.addSubview(label)
		let labelInset = NSDirectionalEdgeInsets(horizontal: 20, vertical: 0)
		constraints += labelContainer.constrain(subview: label, directionalInset: labelInset, activate: false)
		label.textAlignment = .natural
		headerStack.addArrangedSubview(labelContainer)
		headerStack.spacing = 16

		headerStack.addArrangedSubview(drugSelectionCollection)
		constraints += [
			drugSelectionCollection.heightAnchor.constraint(equalToConstant: 44),
			tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
		]

		let config = UICollectionViewCompositionalLayoutConfiguration()
		config.scrollDirection = .horizontal
		let size = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .fractionalHeight(1))
		let item = NSCollectionLayoutItem(layoutSize: size)
		let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitem: item, count: 1)
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
				var config = DrugSelectionConfiguration(text: "Drug")

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
}

extension DosageTableViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard
			let drugID = drugSelectionDataSource.itemIdentifier(for: indexPath),
			let drug = drugController.drug(for: drugID)
		else { return }

		drugController.createDoseEntry(at: Date(), forDrug: drug)
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
		let doseEntry = dosageFetchedResultsController.object(at: indexPath)
		coordinator.dosageTableViewController(self, tappedDosage: doseEntry)
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

