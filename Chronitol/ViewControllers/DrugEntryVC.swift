//
//  ViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit
import CoreData

@MainActor
protocol DrugEntryVCCoordinator: Coordinator {
	func drugEntryVCTappedPlusButton(_ drugEntryVC: DrugEntryVC)
	func drugEntryVC(_ drugEntryVC: DrugEntryVC, tappedDrug drug: DrugEntry)
}

@MainActor
class DrugEntryVC: UIViewController {
	private let tableView = UITableView()
	private var createNewDrugButton: UIBarButtonItem?

	let drugController: DrugController

	private var dataSource: UITableViewDiffableDataSource<String, NSManagedObjectID>!

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

		setupNewDrugButton()

		setupTableView()
		setupDataSource()
	}

	private func setupTableView() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(tableView)
		constraints += view.constrain(subview: tableView, activate: false)

		tableView.delegate = self

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DrugEntryCell")
	}

	private func setupDataSource() {
		dataSource = .init(tableView: tableView, cellProvider: weakify { tableView, indexPath, objectID, strongSelf in
			let cell = tableView.dequeueReusableCell(withIdentifier: "DrugEntryCell", for: indexPath)
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
		let shouldAnimate = tableView.numberOfSections != 0
		dataSource.apply(snap, animatingDifferences: shouldAnimate)
	}
}

extension DrugEntryVC: UITableViewDelegate {
	private func configureDrugCell(_ cell: UITableViewCell, indexPath: IndexPath, objectID: NSManagedObjectID) {
		guard let drug = drugController.drug(for: objectID) else { return }
		let alarms = drug.alarms?.compactMap { $0 as? DrugAlarm } ?? []
		cell.textLabel?.text = drug.name
		cell.detailTextLabel?.text = alarms.map { $0.prettyTimeString }.joined(separator: ", ")
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard
			let drugID = dataSource.itemIdentifier(for: indexPath),
			let drug = drugController.drug(for: drugID)
		else { return }
		coordinator.drugEntryVC(self, tappedDrug: drug)
	}

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let action = UIContextualAction(style: .destructive, title: "Delete", handler: weakify { action, view, completion, strongSelf in
			var successful = false
			defer { completion(successful) }
			guard
				let drugID = strongSelf.dataSource.itemIdentifier(for: indexPath),
				let drug = strongSelf.drugController.drug(for: drugID)
			else { return }
			strongSelf.drugController.deleteDrugEntry(drug)
			successful = true
		})
		return UISwipeActionsConfiguration(actions: [action])
	}
}
