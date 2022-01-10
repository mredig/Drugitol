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
		get async {
			await nc.pendingNotificationRequests()
		}
	}

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
//		pendInfo()
	}

	private func setupActions() {

		let remind30Action = UNNotificationAction(identifier: .drugNotificationRemind30ActionID, title: "Remind me in 30 minutes", options: [])
		let remind15Action = UNNotificationAction(identifier: .drugNotificationRemind15ActionID, title: "Remind me in 15 minutes", options: [])
		let remind5Action = UNNotificationAction(identifier: .drugNotificationRemind5ActionID, title: "Remind me in 5 minutes", options: [])
		let dosageTakenAction = UNNotificationAction(identifier: .drugNotificationDosageTakenActionID, title: "I'm taking it now!", options: [])
		let dosageIgnoredAction = UNNotificationAction(identifier: .drugNotificationDosageIgnoredActionID, title: "Ignore this dose", options: [.destructive])

		let category = UNNotificationCategory(identifier: .drugNotificationCategoryIdentifier,
											  actions: [dosageTakenAction, remind5Action, remind15Action, remind30Action, dosageIgnoredAction],
											  intentIdentifiers: [],
											  options: [.customDismissAction])

		nc.setNotificationCategories([category])
	}

	func pendInfo() {
		nc.getPendingNotificationRequests { requests in
			print("pending")
			requests.forEach { print($0) }
		}

		nc.getDeliveredNotifications { notifications in
			print("delivered")
			notifications.forEach { print($0) }
		}
	}

	func createDrugReminder(for drugAlarm: DrugAlarm?) {
		guard let drugAlarm = drugAlarm else { return }
		var name = "A drug"
		var minute: Int?
		var hour: Int?
		var id: String?

		drugAlarm.managedObjectContext?.performAndWait {
			let drug = drugAlarm.drug
			name = drug?.name ?? name
			minute = drugAlarm.alarmMinute
			hour = drugAlarm.alarmHour
			id = drugAlarm.id?.uuidString
		}
		guard let alarmHour = hour, let alarmMinute = minute, let alarmID = id else { return }
		let userInfo = ["drugName": name]
		createDrugReminder(titled: "Time to take \(name)!", body: "Be sure to take it soon OR YOU'LL DIE", hour: alarmHour, minute: alarmMinute, id: alarmID, userInfo: userInfo)
	}

	func createDrugReminder(titled title: String, body: String, hour: Int, minute: Int, id: String, userInfo: [AnyHashable: Any]) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = UNNotificationSound.default
		content.categoryIdentifier = .drugNotificationCategoryIdentifier
		content.userInfo = userInfo

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

	func createDelayedDrugReminder(titled title: String, body: String, delayedSeconds seconds: TimeInterval, id: String, userInfo: [AnyHashable: Any]) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = UNNotificationSound.default
		content.categoryIdentifier = .drugNotificationCategoryIdentifier
		content.userInfo = userInfo

		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

		let request = UNNotificationRequest(identifier: id + ":delayed", content: content, trigger: trigger)

		nc.add(request) { error in
			if let error = error {
				let string = "\(title) \(body) in \(seconds) \(id)"
				NSLog("Error creating alarm for drug - '\(string)': \(error)")
			}
		}

	}

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
		let userInfo = content.userInfo
		let request = response.notification.request
		if request.trigger is UNTimeIntervalNotificationTrigger {
			deleteDrugAlarm(request: response.notification.request)
		}

		let delayedTitle: String
		if let drugName = userInfo["drugName"] as? String {
			delayedTitle = "Have you taken your \(drugName) yet?"
		} else {
			delayedTitle = content.title
		}

		let identifier = request.identifier.replacingOccurrences(of: ##"\:.*"##, with: "", options: .regularExpression, range: nil)

		switch response.actionIdentifier {
		case UNNotificationDefaultActionIdentifier:
			print("Default")
			createDelayedDrugReminder(titled: delayedTitle, body: content.body, delayedSeconds: 5 * 60, id: identifier, userInfo: userInfo)
		case .drugNotificationRemind5ActionID, UNNotificationDismissActionIdentifier:
			createDelayedDrugReminder(titled: delayedTitle, body: content.body, delayedSeconds: 5 * 60, id: identifier, userInfo: userInfo)
			print("delay 5")
		case .drugNotificationRemind15ActionID:
			createDelayedDrugReminder(titled: delayedTitle, body: content.body, delayedSeconds: 15 * 60, id: identifier, userInfo: userInfo)
			print("delay 15")
		case .drugNotificationRemind30ActionID:
			createDelayedDrugReminder(titled: delayedTitle, body: content.body, delayedSeconds: 30 * 60, id: identifier, userInfo: userInfo)
			print("delay 30")
		case .drugNotificationDosageTakenActionID:
			NotificationCenter.default.post(name: .dosageTakenNotification, object: nil, userInfo: ["id": identifier])
			print("sent notification: \(identifier)")
		default:
			break
		}
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
