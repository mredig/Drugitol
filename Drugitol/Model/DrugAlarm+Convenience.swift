//
//  DrugAlarm+Convenience.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import CoreData

extension DrugAlarm {
	convenience init(alarmTime: TimeInterval, context: NSManagedObjectContext) {
		self.init(context: context)
		self.alarmTime = alarmTime
	}

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "h:mm a"
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter
	}()

	var prettyTimeString: String {
		let time = Date(timeIntervalSince1970: alarmTime)
		return DrugAlarm.formatter.string(from: time)
	}
}
