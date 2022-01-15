//
//  DrugController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Combine

class DrugController: NSObject {

	private let activeDrugsFRC: NSFetchedResultsController<DrugEntry>
	let activeDrugPublisher = CurrentValueSubject<NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, Never>(.init())
	var activeDrugIDs: [NSManagedObjectID] {
		activeDrugPublisher.value.itemIdentifiers
	}

	private let allDrugsFRC: NSFetchedResultsController<DrugEntry>
	let allDrugsPublisher = CurrentValueSubject<NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, Never>(.init())
	var allDrugsIDs: [NSManagedObjectID] {
		allDrugsPublisher.value.itemIdentifiers
	}

	private let dosageListFRC: NSFetchedResultsController<DoseEntry>
	let dosageListPublisher = CurrentValueSubject<NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, Never>(.init())

	let context: NSManagedObjectContext
	let localNotifications = LocalNotifications.shared

	let coreDataStack: CoreDataStack

	init(coreDataStack: CoreDataStack) {
		self.coreDataStack = coreDataStack
		self.context = coreDataStack.mainContext

		let allDrugsFetchRequest: NSFetchRequest<DrugEntry> = DrugEntry.fetchRequest()
		allDrugsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
		self.allDrugsFRC = NSFetchedResultsController<DrugEntry>(
			fetchRequest: allDrugsFetchRequest,
			managedObjectContext: coreDataStack.mainContext,
			sectionNameKeyPath: nil,
			cacheName: nil)

		let activeDrugsFetchRequest: NSFetchRequest<DrugEntry> = DrugEntry.fetchRequest()
		activeDrugsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
		activeDrugsFetchRequest.predicate = NSPredicate(format: "isActive == %i", true)
		self.activeDrugsFRC = NSFetchedResultsController<DrugEntry>(
			fetchRequest: activeDrugsFetchRequest,
			managedObjectContext: coreDataStack.mainContext,
			sectionNameKeyPath: nil,
			cacheName: nil)

		let fetchRequest: NSFetchRequest<DoseEntry> = DoseEntry.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false), NSSortDescriptor(key: "timestamp", ascending: false)]
		self.dosageListFRC = NSFetchedResultsController(
			fetchRequest: fetchRequest,
			managedObjectContext: coreDataStack.mainContext,
			sectionNameKeyPath: "date",
			cacheName: nil)

		super.init()
		activeDrugsFRC.delegate = self
		allDrugsFRC.delegate = self
		dosageListFRC.delegate = self

		fetchFRCs()
	}

	private func fetchFRCs() {
		let frcs: [NSFetchedResultsController<NSManagedObject>]? = [
			activeDrugsFRC,
			allDrugsFRC,
			dosageListFRC,
		] as? [NSFetchedResultsController<NSManagedObject>]
		frcs?.forEach { frc in
			frc.managedObjectContext.performAndWait {
				do {
					try frc.performFetch()
				} catch {
					NSLog("Error fetching frc: \(error)")
				}
			}
		}
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
	func modelObject<T: NSManagedObject>(for id: NSManagedObjectID, on context: NSManagedObjectContext = .mainContext) -> T? {
		do {
			let existingItem = try context.existingObject(with: id)
			return existingItem as? T
		} catch {
			NSLog("Error fetching item: \(error)")
			return nil
		}
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
		localNotifications.createDrugReminder(for: alarm)
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

extension DrugController: NSFetchedResultsControllerDelegate {
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
		let snap = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
		switch controller {
		case activeDrugsFRC:
			activeDrugPublisher.send(snap)
		case allDrugsFRC:
			allDrugsPublisher.send(snap)
		case dosageListFRC:
			dosageListPublisher.send(snap)
		default: break
		}
	}
}

// MARK: - Import/Export
extension DrugController {
	func importFromPlistData(_ data: Data) {

	}

	/// doesn't actually export, but provides the data that can then BE exported
	func exportPlistData() async throws -> Data {
		let fetchRequest = DrugEntry.fetchRequest() as! NSFetchRequest<NSManagedObjectID>
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
		fetchRequest.resultType = .managedObjectIDResultType

		let drugIDs = try await context.perform {
			try fetchRequest.execute()
		}


		var rawDict = [[String: Any]]()
		context.performAndWait {
			for drugID in drugIDs {
				guard let drug: DrugEntry = self.modelObject(for: drugID, on: context) else { continue }
				let alarms: [[String: Any]] = drug.drugAlarms.map {
					["id": $0.id?.uuidString as Any,
					 "alarmHour": $0.alarmHour,
					 "alarmMinute": $0.alarmMinute]
				}
				let dosages: [[String: Any]] = drug.drugDosages.map {
					["date": $0.date as Any,
					 "timestamp": $0.timestamp as Any]
				}
				let drugDict: [String: Any] = [
					"name": drug.name as Any,
					"isActive": drug.isActive,
					"alarms": alarms,
					"takenDosages": dosages]
				rawDict.append(drugDict)
			}
		}

		let plistData: Data
		do {
			plistData = try PropertyListSerialization.data(fromPropertyList: rawDict, format: .binary, options: 0)
		} catch {
			NSLog("Error encoding drug info: \(error)")
			plistData = Data()
		}

		return plistData
	}
}
