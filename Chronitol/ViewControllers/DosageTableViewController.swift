import UIKit
import CoreData
import SwiftPizzaSnips

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

	private var dosageListDataSource: UICollectionViewDiffableDataSource<DosageSection, DosageItem>!
	private var _mostRecentSnapshot: NSDiffableDataSourceSnapshot<DosageSection, DosageItem>?

	private enum DosageSection: Sendable, Hashable {
		case upcoming
		case due
		case fetchedResultsHeader(String)
	}

	public enum DosageItem: Sendable, Hashable {
		case pendingDosage(PendingDosageInfo)
		case dueDosage(PendingDosageInfo)
		case history(NSManagedObjectID)
	}

	typealias PendingDosageInfo = LocalNotifications.PendingDosageInfo

	private static let sectionHeadFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		return formatter
	}()

	private var bag: Bag = []

	private unowned let coordinator: DosageTableViewControllerCoordinator

	private var foregroundingListenerTask: Task<Void, Never>!
	private var notificationShownListenerTask: Task<Void, Never>!

	init(drugController: DrugController, coordinator: DosageTableViewControllerCoordinator) {
		self.drugController = drugController
		self.coordinator = coordinator
		super.init(nibName: nil, bundle: nil)
		self.foregroundingListenerTask = Task { [weak self] in
			var pub = NotificationCenter
				.default
				.publisher(for: UIApplication.willEnterForegroundNotification)
				.values
				.makeAsyncIterator()
			while await pub.next() != nil {
				self?.updatePendingDosages()
			}
		}
		self.foregroundingListenerTask = Task { [weak self] in
			var pub = NotificationCenter
				.default
				.publisher(for: .dosageReminderNotificationShown)
				.values
				.makeAsyncIterator()
			while await pub.next() != nil {
				self?.updatePendingDosages()
			}
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		foregroundingListenerTask?.cancel()
	}

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = "Dosage Log"
		view.backgroundColor = .systemBackground

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
				strongSelf.updateTable(from: snap)
			})
			.store(in: &bag)
	}

	private func setupDebugButton() {
		#if DEBUG
		let item = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(pending))
		navigationItem.rightBarButtonItem = item
		#endif
	}

	@objc func pending() {
		Task {
			let pending = try await LocalNotifications.shared.getPendingDosageInfo()

			pending
				.forEach { print($0) }

		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		dosageListCollection.reloadData()
		updatePendingDosages()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(dosageListCollection)

		var direction = DirectionalToggle.all
		direction.top = .skip
		constraints += view.constrain(dosageListCollection, directions: direction)

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
		let historyCellProvider = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID>(
			handler: weakify { cell, indexPath, objectID, strongSelf in
				guard
					let dosageEntry: DoseEntry = strongSelf.drugController.modelObject(for: objectID)
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

		let pendingCellProvider = UICollectionView.CellRegistration<UICollectionViewListCell, PendingDosageInfo>(
			handler: weakify { cell, indexPath, dosageInfo, strongSelf in
				var config = cell.defaultContentConfiguration()
				config.text = dosageInfo.drugName
				config.secondaryText = dosageInfo.dueTimestampString
				cell.contentConfiguration = config
			})

		dosageListDataSource = .init(collectionView: dosageListCollection, cellProvider: { collectionView, indexPath, objectID in
			switch objectID {
			case .history(let objectID):
				return collectionView.dequeueConfiguredReusableCell(using: historyCellProvider, for: indexPath, item: objectID)
			case .pendingDosage(let dosageInfo), .dueDosage(let dosageInfo):
				return collectionView.dequeueConfiguredReusableCell(using: pendingCellProvider, for: indexPath, item: dosageInfo)
			}
		})

		let headerProvider = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
			elementKind: UICollectionView.elementKindSectionHeader,
			handler: weakify { header, kind, indexPath, strongSelf in
				var config = header.defaultContentConfiguration()
				defer { header.contentConfiguration = config }

				guard
					let section = strongSelf.dosageListDataSource.sectionIdentifier(for: indexPath.section)
				else { return }

				switch section {
				case .upcoming:
					config.text = "Upcoming Dosages"
				case .due:
					config.text = "Due Dosages"
				case .fetchedResultsHeader:
					guard
						let item = strongSelf.dosageListDataSource.itemIdentifier(for: indexPath),
						case .history(let id) = item,
						let dosageEntry: DoseEntry = strongSelf.drugController.modelObject(for: id),
						let date = dosageEntry.date
					else { 
						config.text = "Unknown Date"
						return
					}
					config.text = Self.sectionHeadFormatter.string(from: date)
				}
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

		var directions = DirectionalToggle.all
		directions.bottom = .skip
		let insets = NSDirectionalEdgeInsets(horizontal: 0, vertical: 8)
		constraints += view.constrain(headerStack, inset: insets, safeAreaDirections: .all, directions: directions)

		let label = UILabel()
		label.text = "I just took a dose of..."
		label.font = .italicSystemFont(ofSize: 14)

		let labelContainer = UIView().forAutolayout()
		labelContainer.addSubview(label)
		let labelInset = NSDirectionalEdgeInsets(horizontal: 20, vertical: 0)
		constraints += labelContainer.constrain(label, inset: labelInset)
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

	private func updateTable(from snap: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>) {
		updateTable(from: snap, and: nil)
	}

	private func updatePendingDosages() {
		Task {
			let dosages = try await LocalNotifications
				.shared
				.getPendingDosageInfo()
				.filter {
					switch $0.dueTimestamp {
					case .due: return true
					case .upcoming(let willBeDue):
						return willBeDue.addingTimeInterval(60 * -60) < .now
					}
				}

			updateTable(withPendingDosages: dosages)
		}
	}

	private func updateTable(withPendingDosages pendingDosages: [PendingDosageInfo]) {
		let dosagessss: [DosageSection: [DosageItem]] = pendingDosages
			.nfurcate { info in
				switch info.dueTimestamp {
				case .due:
					return DosageSection.due
				case .upcoming:
					return DosageSection.upcoming
				}
			}
			.mapValues { infoList in
				guard let first = infoList.first else {
					return []
				}
				switch first.dueTimestamp {
				case .due:
					return infoList.map(DosageItem.dueDosage)
				case .upcoming:
					return infoList.map(DosageItem.pendingDosage)
				}
			}

		updateTable(from: nil, and: dosagessss)
	}

	private func updateTable(from historySnap: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>?, and pendingDosages: [DosageSection: [DosageItem]]?) {
		var newSnap = NSDiffableDataSourceSnapshot<DosageSection, DosageItem>()
		let pendingDosages: [DosageSection: [DosageItem]]? = {
			if let out = pendingDosages {
				return out
			} else if let recent = _mostRecentSnapshot {
				var out: [DosageSection: [DosageItem]] = [:]
				if recent.indexOfSection(.upcoming) != nil {
					out[.upcoming] = recent.itemIdentifiers(inSection: .upcoming)
				}
				if recent.indexOfSection(.due) != nil {
					out[.due] = recent.itemIdentifiers(inSection: .due)
				}

				return out
			}
			return nil
		}()
		if let dueDoses = pendingDosages?[.due] {
			newSnap.appendSections([.due])
			newSnap.appendItems(dueDoses, toSection: .due)
		}
		if let upcomingDoses = pendingDosages?[.upcoming] {
			newSnap.appendSections([.upcoming])
			newSnap.appendItems(upcomingDoses, toSection: .upcoming)
		}

		if let historySnap {
			newSnap.appendSections(historySnap.sectionIdentifiers.map(DosageSection.fetchedResultsHeader))
			for sectionID in historySnap.sectionIdentifiers {
				let sectionItems = historySnap.itemIdentifiers(inSection: sectionID)
				newSnap.appendItems(sectionItems.map(DosageItem.history), toSection: DosageSection.fetchedResultsHeader(sectionID))
			}
			if historySnap.reloadedItemIdentifiers.isOccupied {
				newSnap.reloadItems(historySnap.reloadedItemIdentifiers.map(DosageItem.history))
			}
			if historySnap.reconfiguredItemIdentifiers.isOccupied {
				newSnap.reconfigureItems(historySnap.reconfiguredItemIdentifiers.map(DosageItem.history))
			}
			if historySnap.reloadedSectionIdentifiers.isOccupied {
				newSnap.reloadSections(historySnap.reloadedSectionIdentifiers.map(DosageSection.fetchedResultsHeader))
			}
		} else if let recentSnap = _mostRecentSnapshot {
			let disclude = Set([DosageSection.due, .upcoming])
			let ids = recentSnap.sectionIdentifiers.filter { disclude.contains($0) == false }
			newSnap.appendSections(ids)
			for sectionID in ids {
				newSnap.appendItems(recentSnap.itemIdentifiers(inSection: sectionID), toSection: sectionID)
			}
		}

		_mostRecentSnapshot = newSnap
		dosageListDataSource.apply(newSnap, animatingDifferences: true)
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
			let item = dosageListDataSource.itemIdentifier(for: indexPath)
		else { return }
		switch item {
		case .pendingDosage(let doseInfo), .dueDosage(let doseInfo):
			print(doseInfo.drugID)
		case .history(let doseID):
			guard let doseEntry: DoseEntry = drugController.modelObject(for: doseID) else { return }
			coordinator.dosageTableViewController(self, tappedDosage: doseEntry)
		}
	}

	func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let action = UIContextualAction(style: .destructive, title: "Delete", handler: weakify { action, view, completion, strongSelf in
			var successful = false
			defer { completion(successful) }
			guard
				let item = strongSelf.dosageListDataSource.itemIdentifier(for: indexPath)
			else { return }
			switch item {
			case .pendingDosage(let doseInfo), .dueDosage(let doseInfo):
				break
			case .history(let doseID):
				guard
					let dose: DoseEntry = strongSelf.drugController.modelObject(for: doseID)
				else { return }
				strongSelf.drugController.deleteDoseEntry(dose)
				successful = true
			}
		})
		return UISwipeActionsConfiguration(actions: [action])
	}
}

