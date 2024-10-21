import Foundation
import CoreData

extension DoseEntry {
	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "h:mm a"
		return formatter
	}()

	var timeString: String {
		DoseEntry.formatter.string(from: timestamp ?? Date())
	}

	func updateTimestamp(to timestamp: Date) {
		self.timestamp = timestamp
		let calendar = Calendar.current
		let date = calendar.startOfDay(for: timestamp)
		self.date = date
	}

	@discardableResult
	convenience init(timestamp: Date, for drug: DrugEntry, context: NSManagedObjectContext) {
		self.init(context: context)
		self.drug = drug
		updateTimestamp(to: timestamp)
	}
}
