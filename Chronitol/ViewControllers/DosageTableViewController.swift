import UIKit
import CoreData

@MainActor
protocol DosageTableViewControllerCoordinator: Coordinator {
	func dosageTableViewController(_ dosageTableViewController: DosageTableViewController, tappedDosage dosage: DoseEntry)
}

@MainActor
class DosageTableViewController: UIViewController {

	let drugController: DrugController

	private let dosageListCollection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
	private let	drugSelectionCollection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

	private var drugSelectionDataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!

	private let headerStack = UIStackView().forAutolayout()

	private var dosageListDataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!

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
		setupDosageListDataSource()
		setupHeaderStack()
		setupHeaderStackDataSource()

		drugController
			.activeDrugPublisher
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: weakify { snap, strongSelf in
				strongSelf.drugSelectionDataSource.apply(snap, animatingDifferences: true)
			})
			.store(in: &bag)

		drugController
			.dosageListPublisher
			.sink(receiveValue: weakify { snap, strongSelf in
				strongSelf.dosageListDataSource.apply(snap, animatingDifferences: true)
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

		dosageListCollection.reloadData()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(dosageListCollection)

		var createFor: UIView.ConstraintEdgeToggle = true
		createFor.top = false
		constraints += view.constrain(subview: dosageListCollection, createConstraintsFor: createFor, activate: false)

		dosageListCollection.delegate = self

		var config = UICollectionLayoutListConfiguration(appearance: .grouped)
		config.headerMode = .supplementary
		config.trailingSwipeActionsConfigurationProvider = weakify { indexPath, strongSelf in
			strongSelf.trailingSwipeActionsConfiguration(forRowAt: indexPath)
		}
		let layout = UICollectionViewCompositionalLayout.list(using: config)
		dosageListCollection.collectionViewLayout = layout
	}

	private func setupDosageListDataSource() {
		let cellProvider = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID>(
			handler: weakify { cell, indexPath, itemIdentifier, strongSelf in

				guard
					let dosageEntryID = strongSelf.dosageListDataSource.itemIdentifier(for: indexPath), //dosageFetchedResultsController.object(at: indexPath)
					let dosageEntry: DoseEntry = strongSelf.drugController.modelObject(for: dosageEntryID)
				else { return }
				let drugEntry = dosageEntry.drug

				let drugName = drugEntry?.name ?? "A drug"
				let drugNameAttributed = NSMutableAttributedString(string: drugName, attributes: [.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)])

				let timeAttributed = NSAttributedString(string: ": \(dosageEntry.timeString)")
				drugNameAttributed.append(timeAttributed)

				var config = cell.defaultContentConfiguration()
				config.attributedText = drugNameAttributed
				cell.contentConfiguration = config
			})

		dosageListDataSource = .init(collectionView: dosageListCollection, cellProvider: { collectionView, indexPath, objectID in
			collectionView.dequeueConfiguredReusableCell(using: cellProvider, for: indexPath, item: objectID)
		})

		let headerProvider = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
			elementKind: UICollectionView.elementKindSectionHeader,
			handler: weakify { header, kind, indexPath, strongSelf in
				var headerText = "unsure"
				if
					let id = strongSelf.dosageListDataSource.itemIdentifier(for: indexPath),
					let dosageEntry: DoseEntry = strongSelf.drugController.modelObject(for: id),
					let date = dosageEntry.date {

					headerText = Self.sectionHeadFormatter.string(from: date)
				}

				var config = header.defaultContentConfiguration()
				config.text = headerText
				header.contentConfiguration = config
			})
		dosageListDataSource.supplementaryViewProvider = weakify { collectionView, kind, indexPath, strongSelf in
			collectionView.dequeueConfiguredReusableSupplementary(using: headerProvider, for: indexPath)
		}
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
			dosageListCollection.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
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
					let drug: DrugEntry = strongSelf.drugController.modelObject(for: drugID)
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
		switch collectionView {
		case drugSelectionCollection:
			tappedItemOnDrugSelectionCollection(at: indexPath)
		case dosageListCollection:
			tappedItemOnDosageList(at: indexPath)
		default: break
		}
	}

	func tappedItemOnDrugSelectionCollection(at indexPath: IndexPath) {
		guard
			let drugID = drugSelectionDataSource.itemIdentifier(for: indexPath)
		else { return }

		Task {
			await drugController.createDoseEntry(at: Date(), forDrugWithID: drugID)
		}
	}

	func tappedItemOnDosageList(at indexPath: IndexPath) {
		guard
			let doseID = dosageListDataSource.itemIdentifier(for: indexPath),
			let doseEntry: DoseEntry = drugController.modelObject(for: doseID)
		else { return }
		coordinator.dosageTableViewController(self, tappedDosage: doseEntry)
	}

	func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let action = UIContextualAction(style: .destructive, title: "Delete", handler: weakify { action, view, completion, strongSelf in
			var successful = false
			defer { completion(successful) }
			guard
				let doseID = strongSelf.dosageListDataSource.itemIdentifier(for: indexPath),
				let dose: DoseEntry = strongSelf.drugController.modelObject(for: doseID)
			else { return }
			strongSelf.drugController.deleteDoseEntry(dose)
			successful = true
		})
		return UISwipeActionsConfiguration(actions: [action])
	}
}

