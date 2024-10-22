import Foundation
import UIKit
import CoreData
import Combine
import SwiftPizzaSnips

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

	let coreDataStack: ChronCoreDataStack

	init(coreDataStack: ChronCoreDataStack) {
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
	func createDoseEntry(at timestamp: Date, forDrugWithID drugID: NSManagedObjectID) async {
		let context = coreDataStack.container.newBackgroundContext()

		guard let drug: DrugEntry = modelObject(for: drugID, on: context) else { return }

		_ = await context.perform {
			DoseEntry(timestamp: timestamp, for: drug, context: context)

			do {
				try context.save()
			} catch {
				NSLog("Error saving context: \(error)")
			}
		}
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
		var item: T?
		context.performAndWait {
			do {
				let existingItem = try context.existingObject(with: id)
				item = existingItem as? T
			} catch {
				NSLog("Error fetching item: \(error)")
			}
		}
		return item
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
		save(withErrorLogging: "Failed saving drug entry '\(entry)'")

		alarms.forEach { alarm in
			guard let id = alarm.id?.uuidString else { return }
			localNotifications.deleteDrugAlarmNotification(withID: id)
			if isActive {
				Task {
					do {
						try await setupAlarmNotification(alarm.objectID)
					} catch {
						NSLog("Error setting up alarm: \(error)")
					}
				}
			}
		}


		save(withErrorLogging: "Failed updating entry '\(entry)'")
		return entry
	}

	func removeAlarmFromEntry(_ entry: DrugEntry, alarm: DrugAlarm) {
		context.performAndWait {
			entry.removeFromAlarms(alarm)
		}
		localNotifications.deleteDrugAlarmNotification(withID: alarm.id?.uuidString ?? "noid")
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

	private func setupAlarmNotification(_ alarmID: NSManagedObjectID) async throws {
		try await localNotifications.createDrugReminder(forDrugAlarmWithID: alarmID, using: self)
	}

	func getAlarm(withID id: String, on context: NSManagedObjectContext? = nil) -> DrugAlarm? {
		let context = context ?? self.context
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

	private func save(context: NSManagedObjectContext? = nil, withErrorLogging errorLogging: String) {
		let context = context ?? self.context
		do {
			try ChronCoreDataStack.shared.save(context: context)
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

extension DrugController: LocalNotifications.Delegate {
	func localNotifications(_ localNotifications: LocalNotifications, didReceiveDosageTaken dosageID: String) async throws {
		let context = ChronCoreDataStack.shared.container.newBackgroundContext()
		guard
			let drugID = await context.perform({
				let alarm = self.getAlarm(withID: dosageID, on: context)
				return alarm?.drug?.objectID
			})
		else { return }

		await createDoseEntry(at: .now, forDrugWithID: drugID)
	}
}

// MARK: - Import/Export
extension DrugController {
	func clearDB() async throws {
		let dosesFR = DoseEntry.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
		dosesFR.resultType = .managedObjectIDResultType
		let dosesBatch = NSBatchDeleteRequest(fetchRequest: dosesFR)

		let alarmsFR = DrugAlarm.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
		alarmsFR.resultType = .managedObjectIDResultType
		let alarmsBatch = NSBatchDeleteRequest(fetchRequest: alarmsFR)

		let drugFR = DrugEntry.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
		drugFR.resultType = .managedObjectIDResultType
		let drugBatch = NSBatchDeleteRequest(fetchRequest: drugFR)

		let context = ChronCoreDataStack.shared.container.newBackgroundContext()
		try await context.perform {
			func process(result: NSPersistentStoreResult) {
				guard
					let deleteResult = result as? NSBatchDeleteResult,
					let objectIDs = deleteResult.result as? [NSManagedObjectID]
				else { return }

				NSManagedObjectContext.mergeChanges(
					fromRemoteContextSave: [NSDeletedObjectIDsKey: objectIDs],
					into: [context, ChronCoreDataStack.shared.mainContext])
			}

			let doseResult = try context.execute(dosesBatch)
			process(result: doseResult)
			let alarmsResult = try context.execute(alarmsBatch)
			process(result: alarmsResult)
			let drugResult = try context.execute(drugBatch)
			process(result: drugResult)
		}
	}

	func importFromPlistData(_ data: Data) async throws {
		let drugEntries = try (try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]).unwrap()

		let context = ChronCoreDataStack.shared.container.newBackgroundContext()
		try await context.perform {
			for drugEntryDict in drugEntries {
				guard
					let name = drugEntryDict["name"] as? String,
					let isActive = drugEntryDict["isActive"] as? Bool,
					let alarms = drugEntryDict["alarms"] as? [[String: Any]],
					let dosages = drugEntryDict["takenDosages"] as? [[String: Any]]
				else { continue }

				let newDrug = DrugEntry(name: name, isActive: isActive, context: context)

				let drugAlarms: [DrugAlarm] = alarms.compactMap { alarm in
					guard
						let idStr = alarm["id"] as? String,
						let id = UUID(uuidString: idStr),
						let alarmHour = alarm["alarmHour"] as? Int,
						let alarmMinute = alarm["alarmMinute"] as? Int
					else { return nil }
					let alarm = DrugAlarm(alarmHour: alarmHour, alarmMinute: alarmMinute, context: context)
					alarm.id = id
					return alarm
				}
				newDrug.alarms = NSSet(array: drugAlarms)

				for dosage in dosages {
					guard
						let timestamp = dosage["timestamp"] as? Date
					else { continue }

					_ = DoseEntry(timestamp: timestamp, for: newDrug, context: context)
				}
			}
			try context.save()
		}
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
