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
class DrugEntryVC: UIViewController {
	@IBOutlet private weak var tableView: UITableView!
	@IBOutlet private weak var createNewDrugButton: UIBarButtonItem!

	let drugController = DrugController(context: .mainContext)

	private var dataSource: UITableViewDiffableDataSource<String, NSManagedObjectID>!

	private var bag: Bag = []

	override func viewDidLoad() {
		super.viewDidLoad()

		setupTableView()
		setupDataSource()
	}

	private func setupTableView() {
		tableView.delegate = self
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

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)

		if let destVC = segue.destination as? NewDrugViewController {
			if segue.identifier == "NewDrugSegue" {
			}

			if segue.identifier == "EditDrugSegue" {
				guard let indexPath = tableView.indexPathForSelectedRow else { return }

				guard
					let drugID = dataSource.itemIdentifier(for: indexPath),
					let drug = drugController.drug(for: drugID)
				else { return }
				destVC.entry = drug
			}
		}
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
