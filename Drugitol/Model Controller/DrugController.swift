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

	let context: NSManagedObjectContext

	init(context: NSManagedObjectContext) {
		self.context = context
	}

	// MARK: - DrugEntry
	@discardableResult func createDrugEntry(named name: String) -> DrugEntry {
		let entry = DrugEntry(name: name, context: context)

		save(withErrorLogging: "Failed saving new drug entry")
		return entry
	}

	@discardableResult func updateDrugEntry(_ entry: DrugEntry, name: String, alarms: [DrugAlarm]) -> DrugEntry {
		entry.name = name
		entry.alarms = nil
		entry.addToAlarms(NSOrderedSet(array: alarms))

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
