import UserNotifications

protocol TimeNotificationTrigger: UNNotificationTrigger {
	func nextTriggerDate() -> Date?
}

extension UNTimeIntervalNotificationTrigger: TimeNotificationTrigger {}
extension UNCalendarNotificationTrigger: TimeNotificationTrigger {}
