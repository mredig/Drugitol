import UIKit
import CoreData

@MainActor
protocol DrugEntryVCCoordinator: Coordinator {
	func drugEntryVCTappedPlusButton(_ drugEntryVC: DrugEntryVC)
	func drugEntryVC(_ drugEntryVC: DrugEntryVC, tappedDrug drug: DrugEntry)
}

@MainActor
class DrugEntryVC: UIViewController {
	private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
	private var createNewDrugButton: UIBarButtonItem?

	let drugController: DrugController

	private var dataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!

	private var bag: Bag = []

	unowned let coordinator: DrugEntryVCCoordinator

	init(coordinator: DrugEntryVCCoordinator, drugController: DrugController) {
		self.coordinator = coordinator
		self.drugController = drugController
		super.init(nibName: nil, bundle: nil)
	}

		required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = "Drug List"

		setupNewDrugButton()

		setupTableView()
		setupDataSource()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(collectionView)
		constraints += view.constrain(subview: collectionView, activate: false)

		var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
		config.trailingSwipeActionsConfigurationProvider = weakify { indexPath, strongSelf in
			strongSelf.trailingSwipeActionsConfiguration(forRowAt: indexPath)
		}
		let layout = UICollectionViewCompositionalLayout.list(using: config)
		collectionView.collectionViewLayout = layout

		collectionView.delegate = self
	}

	private func setupDataSource() {
		let configuredDrugCell = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID>(
			handler: weakify { cell, indexPath, objectID, strongSelf in
				strongSelf.configureDrugCell(cell, indexPath: indexPath, objectID: objectID)
			})

		dataSource = .init(collectionView: collectionView, cellProvider: weakify { tableView, indexPath, objectID, strongSelf in
			let cell = tableView.dequeueConfiguredReusableCell(using: configuredDrugCell, for: indexPath, item: objectID)
			strongSelf.configureDrugCell(cell, indexPath: indexPath, objectID: objectID)
			return cell
		})

		drugController
			.allDrugsPublisher
			.sink(receiveValue: weakify { snap, strongSelf in
				strongSelf.updateDataSource(from: snap)
			})
			.store(in: &bag)
	}

	private func setupNewDrugButton() {
		let action = UIAction(handler: weakify { action, strongSelf in
			strongSelf.coordinator.drugEntryVCTappedPlusButton(strongSelf)
		})

		createNewDrugButton = UIBarButtonItem(systemItem: .add, primaryAction: action, menu: nil)
		navigationItem.rightBarButtonItem = createNewDrugButton
	}

	private func updateDataSource(from snap: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>) {
		let shouldAnimate = collectionView.numberOfSections != 0
		dataSource.apply(snap, animatingDifferences: shouldAnimate)
	}
}

extension DrugEntryVC: UICollectionViewDelegate {
	private func configureDrugCell(_ cell: UICollectionViewListCell, indexPath: IndexPath, objectID: NSManagedObjectID) {
		guard let drug: DrugEntry = drugController.modelObject(for: objectID) else { return }
		let alarms = drug.alarms?.compactMap { $0 as? DrugAlarm } ?? []

		var config = cell.defaultContentConfiguration()
		config.text = drug.name
		config.secondaryText = alarms.map { $0.prettyTimeString }.joined(separator: ", ")

		cell.contentConfiguration = config
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		collectionView.deselectItem(at: indexPath, animated: false)
		guard
			let drugID = dataSource.itemIdentifier(for: indexPath),
			let drug: DrugEntry = drugController.modelObject(for: drugID)
		else { return }
		coordinator.drugEntryVC(self, tappedDrug: drug)
	}

	func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let action = UIContextualAction(style: .destructive, title: "Delete", handler: weakify { action, view, completion, strongSelf in
			var successful = false
			defer { completion(successful) }
			guard
				let drugID = strongSelf.dataSource.itemIdentifier(for: indexPath),
				let drug: DrugEntry = strongSelf.drugController.modelObject(for: drugID)
			else { return }
			strongSelf.drugController.deleteDrugEntry(drug)
			successful = true
		})
		return UISwipeActionsConfiguration(actions: [action])
	}
}
