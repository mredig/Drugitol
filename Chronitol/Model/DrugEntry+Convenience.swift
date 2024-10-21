import Foundation
import CoreData

extension DrugEntry {

	var drugAlarms: [DrugAlarm] {
		alarms?.compactMap { $0 as? DrugAlarm } ?? []
	}

	var drugDosages: [DoseEntry] {
		takenDosages?.compactMap { $0 as? DoseEntry } ?? []
	}

	convenience init(name: String, isActive: Bool = true, context: NSManagedObjectContext) {
		self.init(context: context)
		self.name = name
		self.isActive = isActive
	}
}
