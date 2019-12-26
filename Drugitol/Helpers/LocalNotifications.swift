//
//  LocalNotifications.swift
//  Poopmaster
//
//  Created by Michael Redig on 9/27/19.
//  Copyright © 2019 Michael Redig. All rights reserved.
//

import UIKit
import UserNotifications

class LocalNotifications: NSObject {
	let nc = UNUserNotificationCenter.current()

	var pendingNotifications: [UNNotificationRequest] {
		var rRequests = [UNNotificationRequest]()
		let semaphore = DispatchSemaphore(value: 0)
		nc.getPendingNotificationRequests { requests in
			rRequests = requests
			semaphore.signal()
		}
		semaphore.wait()
		return rRequests
	}

	static let shared = LocalNotifications()

	override private init() {
		super.init()
		authorizeNotifications()
		setupActions()
		UNUserNotificationCenter.current().delegate = self
	}

	private func authorizeNotifications() {
		nc.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
			// i don't think i need anything here?
			print("Notification permission granted: \(granted)")
			if let error = error {
				NSLog("There was an error requesting notification permission: \(error)")
			}
		}
//		pendInfo()
	}

	private func setupActions() {

		let remind30Action = UNNotificationAction(identifier: .drugNotificationRemind30ActionID, title: "Remind me in 30 minutes", options: [])
		let remind15Action = UNNotificationAction(identifier: .drugNotificationRemind15ActionID, title: "Remind me in 15 minutes", options: [])
		let remind5Action = UNNotificationAction(identifier: .drugNotificationRemind5ActionID, title: "Remind me in 5 minutes", options: [])
		let dosageTakenAction = UNNotificationAction(identifier: .drugNotificationDosageTakenActionID, title: "I just took this dose!", options: [])
		let dosageIgnoredAction = UNNotificationAction(identifier: .drugNotificationDosageIgnoredActionID, title: "Ignore this dose", options: [.destructive])

		let category = UNNotificationCategory(identifier: .drugNotificationCategoryIdentifier,
											  actions: [remind5Action, remind15Action, remind30Action, dosageTakenAction, dosageIgnoredAction],
											  intentIdentifiers: [],
											  options: [])

		nc.setNotificationCategories([category])
	}

//	func pendInfo() {
//		nc.getPendingNotificationRequests { requests in
//			print("pending")
//			requests.forEach { print($0) }
//		}
//
//		nc.getDeliveredNotifications { notifications in
//			print("delivered")
//			notifications.forEach { print($0) }
//		}
//	}

	func createDrugReminder(titled title: String, body: String, hour: Int, minute: Int, id: String) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.badge = NSNumber(value: pendingNotifications.count + 1)
		content.sound = UNNotificationSound.default
		content.categoryIdentifier = .drugNotificationCategoryIdentifier

		var components = DateComponents()
		components.hour = hour
		components.minute = minute
		let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

		let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

		nc.add(request) { error in
			if let error = error {
				let string = "\(title) \(body) at \(hour):\(minute) \(id)"
				NSLog("Error creating alarm for drug - '\(string)': \(error)")
			}
		}
	}

	func createDelayedDrugReminder(titled title: String, body: String, delayedSeconds seconds: TimeInterval, id: String) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.badge = NSNumber(value: pendingNotifications.count + 1)
		content.sound = UNNotificationSound.default
		content.categoryIdentifier = .drugNotificationCategoryIdentifier

		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

		let request = UNNotificationRequest(identifier: id + ":delayed", content: content, trigger: trigger)

		nc.add(request) { error in
			if let error = error {
				let string = "\(title) \(body) in \(seconds) \(id)"
				NSLog("Error creating alarm for drug - '\(string)': \(error)")
			}
		}

	}

//	func createPoopReminder(withTitle title: String, body: String, atTime time: Date, id: String) {
//		let content = UNMutableNotificationContent()
//		content.title = title
//		content.body = body
//		content.badge = 1
//		content.sound = UNNotificationSound.default
////		content.categoryIdentifier = poopNotificationCategoryIdentifier
//
//		let calendar = Calendar.current
//		let components = calendar.dateComponents([.day, .minute, .second, .hour], from: time)
//		let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
//
//		let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
//
//		nc.add(request) { _ in
////			NSLog("scheduled: \(request)!")
//		}
//
////		pendInfo()
//	}

	func deleteDrugAlarm(withID id: String) {
		nc.removeDeliveredNotifications(withIdentifiers: [id])
		nc.removePendingNotificationRequests(withIdentifiers: [id])
	}

	func deleteDrugAlarm(request: UNNotificationRequest) {
		deleteDrugAlarm(withID: request.identifier)
	}

	func deleteDeliveredReminders() {
		nc.removeAllDeliveredNotifications()
	}
}

extension LocalNotifications: UNUserNotificationCenterDelegate {
	func userNotificationCenter(_ center: UNUserNotificationCenter,
								didReceive response: UNNotificationResponse,
								withCompletionHandler completionHandler: @escaping () -> Void) {
		print("did receive: \(response)")
		defer { completionHandler() }

		let content = response.notification.request.content
		let request = response.notification.request
//		LocalNotifications.shared.deleteDrugAlarm(request: response.notification.request)
		UIApplication.shared.applicationIconBadgeNumber = pendingNotifications.count

		let identifier = request.identifier.replacingOccurrences(of: ##"\:.*"##, with: "", options: .regularExpression, range: nil)

		switch response.actionIdentifier {
		case UNNotificationDismissActionIdentifier:
			print("Dismiss action")
		case UNNotificationDefaultActionIdentifier:
			print("Default")
		case .drugNotificationRemind5ActionID:
			createDelayedDrugReminder(titled: content.title, body: content.body, delayedSeconds: 5 * 60, id: identifier)
			print("delay 5")
		case .drugNotificationRemind15ActionID:
			createDelayedDrugReminder(titled: content.title, body: content.body, delayedSeconds: 15 * 60, id: identifier)
			print("delay 15")
		case .drugNotificationRemind30ActionID:
			createDelayedDrugReminder(titled: content.title, body: content.body, delayedSeconds: 30 * 60, id: identifier)
			print("delay 30")
		case .drugNotificationDosageTakenActionID:
			NotificationCenter.default.post(name: .dosageTakenNotification, object: nil, userInfo: ["id": identifier])
		default:
			break
		}

//		NotificationCenter.default.post(name: .kUNNotificationRecieved, object: nil, userInfo: ["id": response.notification.request.identifier])
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter,
								willPresent notification: UNNotification,
								withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.alert, .sound])
	}
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
