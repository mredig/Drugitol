import UIKit
import UserNotifications
import Foundation
import CoreData

class LocalNotifications: NSObject {
	let nc = UNUserNotificationCenter.current()

	static let drugNameKey = "drugName"
	static let alarmObjectIDKey = "alarmObjectID"
	static let drugObjectIDKey = "drugObjectID"

	static let shared = LocalNotifications()

	override private init() {
		super.init()
		authorizeNotifications()
		setupActions()
		UNUserNotificationCenter.current().delegate = self
	}

	private func authorizeNotifications() {
		nc.requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, error in
			// i don't think i need anything here?
			print("Notification permission granted: \(granted)")
			if let error = error {
				NSLog("There was an error requesting notification permission: \(error)")
			}
		}
	}

	private func setupActions() {

		let remind30Action = UNNotificationAction(identifier: .drugNotificationRemind30ActionID, title: "Remind me in 30 minutes", options: [])
		let remind15Action = UNNotificationAction(identifier: .drugNotificationRemind15ActionID, title: "Remind me in 15 minutes", options: [])
		let remind5Action = UNNotificationAction(identifier: .drugNotificationRemind5ActionID, title: "Remind me in 5 minutes", options: [])
		let dosageTakenAction = UNNotificationAction(identifier: .drugNotificationDosageTakenActionID, title: "I'm taking it now!", options: [])
		let dosageIgnoredAction = UNNotificationAction(identifier: .drugNotificationDosageIgnoredActionID, title: "Ignore this dose", options: [.destructive])

		let category = UNNotificationCategory(
			identifier: .drugNotificationCategoryIdentifier,
			actions: [dosageTakenAction, remind5Action, remind15Action, remind30Action, dosageIgnoredAction],
			intentIdentifiers: [],
			options: [.customDismissAction])

		nc.setNotificationCategories([category])
	}

	func getPendingDosageInfo() async throws -> [PendingDosageInfo] {
		async let pendingNotifications = nc.pendingNotificationRequests()
			.asyncConcurrentMap { request in
				let trigger = request.trigger as? TimeNotificationTrigger
				let name = request.content.userInfo[Self.drugNameKey] as? String ?? request.content.title
				let id = (request.content.userInfo[Self.drugObjectIDKey] as? String).flatMap(URL.init(string:))
				return PendingDosageInfo(
					alarmID: request.identifier,
					drugID: id,
					dueTimestamp: .upcoming(trigger?.nextTriggerDate() ?? .now.addingTimeInterval(-60)),
					drugName: name)
			}
		async let deliveredNotifications = nc.deliveredNotifications()
			.asyncConcurrentMap { notification in
				let request = notification.request
				let name = request.content.userInfo[Self.drugNameKey] as? String ?? request.content.title
				let id = (request.content.userInfo[Self.drugObjectIDKey] as? String).flatMap(URL.init(string:))
				return PendingDosageInfo(
					alarmID: request.identifier,
					drugID: id,
					dueTimestamp: .due(notification.date),
					drugName: name)
			}

		return await deliveredNotifications + pendingNotifications
	}

	func createDrugReminder(forDrugAlarmWithID alarmID: NSManagedObjectID, using drugController: DrugController) async throws {
		let context = drugController.coreDataStack.container.newBackgroundContext()
		let info = try await context.perform(
			{ () -> (name: String, minute: Int, hour: Int, id: String, drugURI: URL) in
				guard
					let drugAlarm: DrugAlarm = drugController.modelObject(for: alarmID, on: context),
					let name = drugAlarm.drug?.name,
					let drugURI = drugAlarm.drug?.objectID.uriRepresentation(),
					let alarmID = drugAlarm.id?.uuidString
				else { throw NotificationError.noAssociatedItemFound }
				let minute = drugAlarm.alarmMinute
				let hour = drugAlarm.alarmHour

				return (name, minute, hour, alarmID, drugURI)
			})

		let userInfo: [AnyHashable: Any] = [
			Self.drugNameKey: info.name,
			Self.alarmObjectIDKey: alarmID.uriRepresentation().absoluteString,
			Self.drugObjectIDKey: info.drugURI.absoluteString,
		]
		let title = "Time to take \(info.name)!"
		let body = "Be sure to take it soon OR YOU'LL DIE"

		do {
			try await createDrugReminder(
				titled: title,
				body: body,
				scheduleInfo: .specificTime(hour: info.hour, minute: info.minute),
				id: info.id,
				userInfo: userInfo)
		} catch {
			let string = "\(title) \(body) at \(info.hour):\(info.minute) \(alarmID)"
			NSLog("Error creating alarm for drug - '\(string)': \(error)")
		}
	}

	enum SchedulingInfo {
		case delayedFromNow(seconds: TimeInterval)
		case specificTime(hour: Int, minute: Int)
	}

	func createDrugReminder(titled title: String, body: String, scheduleInfo: SchedulingInfo, id: String, userInfo: [AnyHashable: Any]) async throws {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = .criticalSoundNamed(UNNotificationSoundName("pill_shake.caf"))
		content.categoryIdentifier = .drugNotificationCategoryIdentifier
		content.userInfo = userInfo
		content.interruptionLevel = .critical
		content.threadIdentifier = userInfo["drugName"] as? String ?? "Chronitol"

		let request: UNNotificationRequest
		switch scheduleInfo {
		case .delayedFromNow(let seconds):
			let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

			request = UNNotificationRequest(identifier: id + ":delayed", content: content, trigger: trigger)
		case .specificTime(let hour, let minute):
			var components = DateComponents()
			components.hour = hour
			components.minute = minute
			let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

			request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
		}

		try await nc.add(request)
	}

	func deleteDrugAlarmNotification(withAlarmID alarmID: NSManagedObjectID) async {
		let notificationRequests = await withTaskGroup(
			of: [UNNotificationRequest].self,
			body: { [nc] group -> [UNNotificationRequest] in
				group.addTask {
					await nc.pendingNotificationRequests()
				}
				group.addTask {
					await nc.deliveredNotifications().map(\.request)
				}

				var out: [UNNotificationRequest] = []
				for await array in group {
					out.append(contentsOf: array)
				}
				return out
			})

		let alarmIDStr = alarmID.uriRepresentation().absoluteString
		let alarmNotifications = notificationRequests
			.filter { request in
				request.content.userInfo[Self.alarmObjectIDKey] as? String == alarmIDStr
			}
		alarmNotifications.forEach { request in
			deleteDrugAlarmNotification(request: request)
		}
	}

	func deleteDrugAlarmNotification(request: UNNotificationRequest) {
		deleteDrugAlarmNotification(withID: request.identifier)
	}

	func deleteDrugAlarmNotification(withID id: String) {
		nc.removeDeliveredNotifications(withIdentifiers: [id])
		nc.removePendingNotificationRequests(withIdentifiers: [id])
	}

	func deleteDeliveredReminders() {
		nc.removeAllDeliveredNotifications()
	}
}

extension LocalNotifications: UNUserNotificationCenterDelegate {
	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse,
		withCompletionHandler completionHandler: @escaping () -> Void) {
			print("did receive: \(response.actionIdentifier)")
			defer { completionHandler() }

			let content = response.notification.request.content
			let userInfo = content.userInfo
			let request = response.notification.request
			if request.trigger is UNTimeIntervalNotificationTrigger {
				deleteDrugAlarmNotification(request: response.notification.request)
			}

			let delayedTitle: String
			if let drugName = userInfo["drugName"] as? String {
				delayedTitle = "Have you taken your \(drugName) yet?"
			} else {
				delayedTitle = content.title
			}

			let identifier = request.identifier.replacingOccurrences(of: ##"\:.*"##, with: "", options: .regularExpression, range: nil)

			Task {
				switch response.actionIdentifier {
				case .drugNotificationRemind5ActionID, UNNotificationDismissActionIdentifier, UNNotificationDefaultActionIdentifier:
					try await createDrugReminder(titled: delayedTitle, body: content.body, scheduleInfo: .delayedFromNow(seconds: 5 * 60), id: identifier, userInfo: userInfo)
					print("delay 5")
				case .drugNotificationRemind15ActionID:
					try await createDrugReminder(titled: delayedTitle, body: content.body, scheduleInfo: .delayedFromNow(seconds: 15 * 60), id: identifier, userInfo: userInfo)
					print("delay 15")
				case .drugNotificationRemind30ActionID:
					try await createDrugReminder(titled: delayedTitle, body: content.body, scheduleInfo: .delayedFromNow(seconds: 30 * 60), id: identifier, userInfo: userInfo)
					print("delay 30")
				case .drugNotificationDosageTakenActionID:
					NotificationCenter.default.post(name: .dosageTakenNotification, object: nil, userInfo: ["id": identifier])
					print("sent notification: \(identifier)")
				default:
					break
				}
			}
		}

	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification,
		withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
			completionHandler([.banner, .sound, .list])
		}

	struct PendingDosageInfo: Codable, Hashable, Sendable {
		let alarmID: String
		let drugID: URL?
		let dueTimestamp: TimeRelativity
		enum TimeRelativity: Codable, Hashable, Sendable {
			case upcoming(Date)
			case due(Date)

			var date: Date {
				switch self {
				case .upcoming(let date), .due(let date):
					date
				}
			}
		}

		let drugName: String
		var dueTimestampString: String {
			Self.dateFormatter.string(from: dueTimestamp.date)
		}

		private static let dateFormatter = DateFormatter().with {
			$0.dateStyle = .short
			$0.timeStyle = .short
			$0.doesRelativeDateFormatting = true
		}
	}
}

enum NotificationError: Error, LocalizedError {
	case noAssociatedItemFound

	var errorDescription: String? { "\(NotificationError.noAssociatedItemFound)" }
}

fileprivate extension String {
	static let drugNotificationCategoryIdentifier = "com.redeggproductions.drugNotificationActions"

	static let drugNotificationRemind30ActionID = "com.redeggproductions.drugNotificationRemind30"
	static let drugNotificationRemind15ActionID = "com.redeggproductions.drugNotificationRemind15"
	static let drugNotificationRemind5ActionID = "com.redeggproductions.drugNotificationRemind5"
	static let drugNotificationDosageTakenActionID = "com.redeggproductions.drugNotificationDosageTaken"
	static let drugNotificationDosageIgnoredActionID = "com.redeggproductions.drugNotificationDosageIgnored"
}

extension NSNotification.Name {
	static let dosageTakenNotification = NSNotification.Name(rawValue: "com.redeggproductions.dosageTaken")
}
