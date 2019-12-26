//
//  AlarmNumberConverter.swift
//  Drugitol
//
//  Created by Michael Redig on 12/25/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

struct AlarmNumberConverter {

	let alarmHour: Int
	let alarmMinute: Int

	var components: DateComponents {
		let calendar = Calendar.current
		return calendar.dateComponents([.hour, .minute], from: date)
	}

	var date: Date {
		let calendar = Calendar.current
		let day = calendar.startOfDay(for: Date())
		guard let dayHour = calendar.date(byAdding: .hour, value: alarmHour, to: day) else { fatalError("Error creating date: \(self)") }
		guard let dayHourMinute = calendar.date(byAdding: .minute, value: alarmMinute, to: dayHour) else { fatalError("Error creating date: \(self)") }

		return dayHourMinute
	}

	var alarmComponents: TimeSelectionViewController.AlarmTimeComponents {
		(alarmHour, alarmMinute)
	}
}
