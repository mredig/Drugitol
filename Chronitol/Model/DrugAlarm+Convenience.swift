import Foundation
import SwiftPizzaSnips
import CoreData

extension DrugAlarm {
	var alarmHour: Int {
		get { Int(alarmHour16) }
		set { alarmHour16 = Int16(min(newValue, Int(Int16.max))) }
	}

	var alarmMinute: Int {
		get { Int(alarmMinute16) }
		set { alarmMinute16 = Int16(min(newValue, Int(Int16.max))) }
	}

	convenience init(alarmHour: Int, alarmMinute: Int, context: NSManagedObjectContext) {
		self.init(context: context)
		self.alarmHour = alarmHour
		self.alarmMinute = alarmMinute
		self.id = UUID()
	}

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "h:mm a"
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter
	}()

	var prettyTimeString: String {
		let minutesFromMidnight = alarmMinute + alarmHour * 60
		let secondsFromMidnight = TimeInterval(minutesFromMidnight * 60)
		let time = Date(timeIntervalSince1970: secondsFromMidnight)
		return DrugAlarm.formatter.string(from: time)
	}

	public override func prepareForDeletion() {
		super.prepareForDeletion()

		let idURL = objectID.uriRepresentation()
		DefaultsManager.shared[.delayedAlarms].removeAll(where: { $0.alarmIDURL == idURL })
	}
}
