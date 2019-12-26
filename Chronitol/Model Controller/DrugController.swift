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
	let localNotifications = LocalNotifications.shared

	init(context: NSManagedObjectContext) {
		self.context = context
	}

	// MARK: - FRC
	func createDosageFetchedResultsController(withDelegate delegate: NSFetchedResultsControllerDelegate) -> NSFetchedResultsController<DoseEntry> {
		let fetchRequest: NSFetchRequest<DoseEntry> = DoseEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false), NSSortDescriptor(key: "timestamp", ascending: false)]

		let moc = CoreDataStack.shared.mainContext
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
																  managedObjectContext: moc,
																  sectionNameKeyPath: "date",
																  cacheName: nil)
		fetchedResultsController.delegate = delegate
		do {
			try fetchedResultsController.performFetch()
		} catch {
			print("error performing initial fetch for frc: \(error)")
		}
		return fetchedResultsController
	}

	func createDrugFetchedResultsController(withDelegate delegate: NSFetchedResultsControllerDelegate?) -> NSFetchedResultsController<DrugEntry> {
		let fetchRequest: NSFetchRequest<DrugEntry> = DrugEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

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

	func updateDoseEntry(_ entry: DoseEntry, timestamp: Date) {
		context.performAndWait {
			entry.updateTimestamp(to: timestamp)
		}

		save(withErrorLogging: "Failed updating dose entry: \(entry)")
	}

	func deleteDoseEntry(_ entry: DoseEntry) {
		context.performAndWait {
			context.delete(entry)
		}
		save(withErrorLogging: "Failed deleting DoseEntry: \(entry)")
	}

	// MARK: - DrugEntry
	private func getActiveDrugs() -> [DrugEntry] {
		let fetchRequest: NSFetchRequest<DrugEntry> = DrugEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

		fetchRequest.predicate = NSPredicate(format: "isActive == %i", true)

		var entries: [DrugEntry] = []
		context.performAndWait {
			do {
				entries = try context.fetch(fetchRequest)
			} catch {
				NSLog("Error fetching drugs: \(error)")
			}
		}
		return entries
	}

	@discardableResult func createDrugEntry(named name: String) -> DrugEntry {
		let entry = DrugEntry(name: name, context: context)

		save(withErrorLogging: "Failed saving new drug entry")
		return entry
	}

	@discardableResult func updateDrugEntry(_ entry: DrugEntry, name: String, isActive: Bool, alarms: [DrugAlarm]) -> DrugEntry {
		context.performAndWait {
			entry.name = name
			entry.alarms = nil
			entry.isActive = isActive
			entry.addToAlarms(NSSet(array: alarms))
		}

		alarms.forEach {
			guard let id = $0.id?.uuidString else { return }
			localNotifications.deleteDrugAlarm(withID: id)
			if isActive {
				setupAlarmNotification($0)
			}
		}


		save(withErrorLogging: "Failed updating entry '\(entry)'")
		return entry
	}

	func removeAlarmFromEntry(_ entry: DrugEntry, alarm: DrugAlarm) {
		context.performAndWait {
			entry.removeFromAlarms(alarm)
		}
		localNotifications.deleteDrugAlarm(withID: alarm.id?.uuidString ?? "noid")
		save(withErrorLogging: "Failed removing alarm '\(alarm)' from entry '\(entry)'")
	}

	func deleteDrugEntry(_ entry: DrugEntry) {
		context.performAndWait {
			context.delete(entry)
		}

		save(withErrorLogging: "Error deleting entry")
	}

	// MARK: - DrugAlarm
	@discardableResult func createDrugAlarm(alarmHour: Int, alarmMinute: Int) -> DrugAlarm {
		let alarm = DrugAlarm(alarmHour: alarmHour, alarmMinute: alarmMinute, context: context)

		save(withErrorLogging: "Failed saving new drug alarm")
		return alarm
	}

	@discardableResult func updateDrugAlarm(_ alarm: DrugAlarm, alarmHour: Int, alarmMinute: Int) -> DrugAlarm {
		context.performAndWait {
			alarm.alarmHour = alarmHour
			alarm.alarmMinute = alarmMinute
		}

		save(withErrorLogging: "Failed updating drug alarm")
		return alarm
	}

	private func setupAlarmNotification(_ alarm: DrugAlarm) {
		var name = "A drug"
		var minute: Int?
		var hour: Int?
		var id: String?

		context.performAndWait {
			let drug = alarm.drug
			name = drug?.name ?? name
			minute = alarm.alarmMinute
			hour = alarm.alarmHour
			id = alarm.id?.uuidString
		}

		guard let alarmHour = hour, let alarmMinute = minute, let alarmID = id else { return }
		localNotifications.createDrugReminder(titled: "Time to take \(name)!", body: "Be sure to take it soon OR YOU'LL DIE", hour: alarmHour, minute: alarmMinute, id: alarmID)
	}

	func getAlarm(withID id: String) -> DrugAlarm? {
		let fetchRequest: NSFetchRequest<DrugAlarm> = DrugAlarm.fetchRequest()

		guard let uuid = UUID(uuidString: id) else { return nil }
		fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as NSUUID)

		var alarm: DrugAlarm?
		context.performAndWait {
			do {
				alarm = try context.fetch(fetchRequest).first
			} catch {
				NSLog("Error fetching alarm: \(error)")
			}
		}
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
