import Foundation
import SwiftPizzaSnips

struct DelayedAlarmInfo: Sendable, Codable, Hashable {
	let scheduleAfter: Date
	let alarmIDURL: URL
}
extension DefaultsManager.KeyWithDefault where Value == [DelayedAlarmInfo], StoredValue == Data {
	static let delayedAlarms = Self.init("delayedAlarms", defaultValue: [])
		.withTransform(
			get: {
				try DefaultsManager.defaultDecoder.decode([DelayedAlarmInfo].self, from: $0)
			},
			set: {
				try DefaultsManager.defaultEncoder.encode($0)
			})
}
