//
//  CoreDataStack.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//
//swiftlint:disable untyped_error_in_catch

import Foundation
import CoreData

class CoreDataStack {
	static let shared = CoreDataStack()
	
	private init() {
		setupNotificationObservers()
	}

	/// A generic function to save any context we want (main or background)
	func save(context: NSManagedObjectContext) throws {
		//Placeholder in case something doesn't work
		var error: Error?

		context.performAndWait {
			do {
				try context.save()
			} catch let saveError {
				NSLog("error saving moc: \(saveError)")
				error = saveError
			}
		}
		if let error = error {
			throw error
		}
	}

	/// Access to the Persistent Container
	lazy var container: NSPersistentContainer = {
		let container = NSPersistentContainer(name: "Drugs")
		container.loadPersistentStores(completionHandler: { _, error in
			if let error = error {
				fatalError("Failed to load persistent store: \(error)")
			}
		})
		// May need to be disabled if dataset is too large for performance reasons
		container.viewContext.automaticallyMergesChangesFromParent = true
		return container
	}()

	var mainContext: NSManagedObjectContext {
		return container.viewContext
	}
}

// MARK: - custom stuff
extension CoreDataStack {
	private func setupNotificationObservers() {
		_ = NotificationCenter.default.addObserver(forName: .dosageTakenNotification, object: nil, queue: nil, using: { [weak self] notification in
			print("got notification \(notification)")
			guard let self = self else { return }
			guard let id = notification.userInfo?["id"] as? String else { return }
			let drugController = DrugController(context: self.container.newBackgroundContext())
			guard let alarm = drugController.getAlarm(withID: id), let drug = alarm.drug else { return }

			drugController.createDoseEntry(at: Date(), forDrug: drug)
		})
	}
}

extension NSManagedObjectContext {
	static let mainContext = CoreDataStack.shared.mainContext
}
