import UIKit
import SwiftPizzaSnips
import UserNotifications
import Foundation
import CoreData

class LocalNotifications: NSObject {
	protocol Delegate: AnyObject {
		func localNotifications(_ localNotifications: LocalNotifications, didReceiveDosageTaken dosageID: String) async throws
	}

	let nc = UNUserNotificationCenter.current()

	static let drugNameKey = "drugName"
	static let alarmObjectIDKey = "alarmObjectID"
	static let drugObjectIDKey = "drugObjectID"

	static let shared = LocalNotifications()

	weak var delegate: Delegate?

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

		let remind30Action = UNNotificationAction(identifier: NotificationDelay.remindIn30.rawValue, title: "Remind me in 30 minutes", options: [])
		let remind15Action = UNNotificationAction(identifier: NotificationDelay.remindIn15.rawValue, title: "Remind me in 15 minutes", options: [])
		let remind5Action = UNNotificationAction(identifier: NotificationDelay.remindIn5.rawValue, title: "Remind me in 5 minutes", options: [])
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
					notificationID: request.identifier,
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
					notificationID: request.identifier,
					drugID: id,
					dueTimestamp: .due(notification.date),
					drugName: name)
			}

		return await deliveredNotifications + pendingNotifications
	}

	@MainActor
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

	@MainActor
	func createDrugReminder(
		titled title: String,
		body: String,
		scheduleInfo: SchedulingInfo,
		id: String,
		userInfo: [AnyHashable: Any]
	) async throws {
		defer { NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil) }
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
		case .specificTime(hour: let hour, minute: let minute):
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
		NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil)
	}

	func deleteDeliveredReminders() {
		nc.removeAllDeliveredNotifications()
		NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil)
	}

	func deleteAllReminders() {
		nc.removeAllDeliveredNotifications()
		nc.removeAllPendingNotificationRequests()
		NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil)
	}

	func resolveDeliveredNotification(withID id: String) {
		nc.removeDeliveredNotifications(withIdentifiers: [id])
		NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil)
	}

	@MainActor
	func createDelayedReminder(from request: UNNotificationRequest, delay: NotificationDelay) async throws {
		let content = request.content
		let delayedTitle = {
			guard
				let drugName = content.userInfo[Self.drugNameKey] as? String
			else { return content.title }
			return "Have you taken your \(drugName) yet?"
		}()
		try await createDrugReminder(
			titled: delayedTitle,
			body: content.body,
			scheduleInfo: .delayedFromNow(seconds: delay.seconds),
			id: request.identifier,
			userInfo: content.userInfo)
	}

	@MainActor
	func createDelayedReminder(from dosageInfo: PendingDosageInfo, delayedUntilAfter: Date) throws {
		let alarmIDURL = try dosageInfo.drugID.unwrap("No drug ID URL")
		let delayedInfo = DelayedAlarmInfo(
			scheduleAfter: delayedUntilAfter,
			alarmIDURL: alarmIDURL)
		DefaultsManager.shared[.delayedAlarms].append(delayedInfo)
	}
}

extension LocalNotifications: UNUserNotificationCenterDelegate {
	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse,
		withCompletionHandler completionHandler: @escaping () -> Void) {
			print("did receive: \(response.actionIdentifier)")
			defer { completionHandler() }

			let request = response.notification.request
			if request.trigger is UNTimeIntervalNotificationTrigger {
				deleteDrugAlarmNotification(request: response.notification.request)
			}

			let cleanIdentifier = String(request.identifier.prefix(while: { $0 != ":" }))

			Task {
				defer { NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil) }
				guard
					let delay = NotificationDelay(rawValue: response.actionIdentifier)
				else {
					guard response.actionIdentifier == .drugNotificationDosageTakenActionID else { return }
					guard let delegate else {
						return NSLog("No delegate when trying to mark dosage taken!")
					}
					try await delegate.localNotifications(self, didReceiveDosageTaken: cleanIdentifier)
					print("marked as taken: \(cleanIdentifier)")
					return
				}
				return try await createDelayedReminder(from: request, delay: delay)
			}
		}

	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification,
		withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
			completionHandler([.banner, .sound, .list])
			NotificationCenter.default.post(name: .dosageReminderNotificationsChanged, object: nil)
		}

	struct PendingDosageInfo: Codable, Hashable, Sendable {
		let notificationID: String
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

	static let drugNotificationDosageTakenActionID = "com.redeggproductions.drugNotificationDosageTaken"
	static let drugNotificationDosageIgnoredActionID = "com.redeggproductions.drugNotificationDosageIgnored"
}

extension NSNotification.Name {
	static let dosageReminderNotificationsChanged = NSNotification.Name(rawValue: "com.redeggproductions.remindersChanged")
}

enum NotificationDelay: String, Sendable, Hashable, CaseIterable {
	case remindIn30 = "com.redeggproductions.drugNotificationRemind30"
	case remindIn15 = "com.redeggproductions.drugNotificationRemind15"
	case remindIn5 = "com.redeggproductions.drugNotificationRemind5"

	var seconds: Double {
		switch self {
		case .remindIn5:
			5 * 60
		case .remindIn15:
			15 * 60
		case .remindIn30:
			30 * 60
		}
	}
}
