//
//  DrugController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import CoreData

class DrugController {

	var activeDrugs: [DrugEntry] {
		getActiveDrugs()
	}

	let context: NSManagedObjectContext

	init(context: NSManagedObjectContext) {
		self.context = context
	}

	// MARK: - FRC
	func createDosageFetchedResultsController(withDelegate delegate: NSFetchedResultsControllerDelegate) -> NSFetchedResultsController<DoseEntry> {
		let fetchRequest: NSFetchRequest<DoseEntry> = DoseEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

		let moc = CoreDataStack.shared.mainContext
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
																  managedObjectContext: moc,
																  sectionNameKeyPath: nil,
																  cacheName: nil)
		fetchedResultsController.delegate = delegate
		do {
			try fetchedResultsController.performFetch()
		} catch {
			print("error performing initial fetch for frc: \(error)")
		}
		return fetchedResultsController
	}

	// MARK: - DoseEntry

	@discardableResult func createDoseEntry(at timestamp: Date, forDrug drug: DrugEntry) -> DoseEntry {
		let entry = DoseEntry(timestamp: timestamp, for: drug, context: context)

		save(withErrorLogging: "Failed saving new dose entry")
		return entry
	}

	func deleteDoseEntry(_ entry: DoseEntry) {
		context.delete(entry)
		save(withErrorLogging: "Failed deleting DoseEntry: \(entry)")
	}


	// MARK: - DrugEntry

	private func getActiveDrugs() -> [DrugEntry] {
		let fetchRequest: NSFetchRequest<DrugEntry> = DrugEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

		fetchRequest.predicate = NSPredicate(format: "isActive == %i", true)

		do {
			return try context.fetch(fetchRequest)
		} catch {
			NSLog("Error fetching drugs: \(error)")
			return []
		}
	}

	@discardableResult func createDrugEntry(named name: String) -> DrugEntry {
		let entry = DrugEntry(name: name, context: context)

		save(withErrorLogging: "Failed saving new drug entry")
		return entry
	}

	@discardableResult func updateDrugEntry(_ entry: DrugEntry, name: String, isActive: Bool, alarms: [DrugAlarm]) -> DrugEntry {
		entry.name = name
		entry.alarms = nil
		entry.isActive = isActive
		entry.addToAlarms(NSSet(array: alarms))

		save(withErrorLogging: "Failed updating entry '\(entry)'")
		return entry
	}

	func removeAlarmFromEntry(_ entry: DrugEntry, alarm: DrugAlarm) {
		entry.removeFromAlarms(alarm)
		save(withErrorLogging: "Failed removing alarm '\(alarm)' from entry '\(entry)'")
	}

	func deleteDrugEntry(_ entry: DrugEntry) {
		context.delete(entry)

		save(withErrorLogging: "Error deleting entry")
	}

	// MARK: - DrugAlarm
	@discardableResult func createDrugAlarm(alarmTime: TimeInterval) -> DrugAlarm {
		let alarm = DrugAlarm(alarmTime: alarmTime, context: context)

		save(withErrorLogging: "Failed saving new drug alarm")
		return alarm
	}

	@discardableResult func updateDrugAlarm(_ alarm: DrugAlarm, alarmTime: TimeInterval) -> DrugAlarm {
		alarm.alarmTime = alarmTime

		save(withErrorLogging: "Failed updating drug alarm")
		return alarm
	}

	private func save(withErrorLogging errorLogging: String) {
		do {
			try CoreDataStack.shared.save(context: context)
		} catch {
			NSLog("\(errorLogging): \(error)")
		}
	}
}
