//swiftlint:disable untyped_error_in_catch

import Foundation
import CoreData

class ChronCoreDataStack {
	static let shared = ChronCoreDataStack()
	
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
extension ChronCoreDataStack {
	private func setupNotificationObservers() {
		_ = NotificationCenter.default.addObserver(forName: .dosageTakenNotification, object: nil, queue: nil, using: { [weak self] notification in
			print("got notification \(notification)")
			guard let self = self else { return }
			guard let id = notification.userInfo?["id"] as? String else { return }
			let drugController = DrugController(coreDataStack: self)

			Task {
				let context = self.container.newBackgroundContext()
				var drugID: NSManagedObjectID?
				context.performAndWait {
					guard
						let alarm = drugController.getAlarm(withID: id, on: context)
					else { return }
					drugID = alarm.drug?.objectID
				}
				guard let drugID = drugID else { return }
				await drugController.createDoseEntry(at: Date(), forDrugWithID: drugID)
			}
		})
	}
}

extension NSManagedObjectContext {
	static let mainContext = ChronCoreDataStack.shared.mainContext
}
