//
//  TimeSelectionViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

protocol TimeSelectionViewControllerDelegate: AnyObject {
	func timeSelectionVC(_ timeSelectionVC: TimeSelectionViewController, didSelectTime time: (hour: Int, minute: Int))
}

class TimeSelectionViewController: UIViewController {
	@IBOutlet private var selectedTimeLabel: UIBarButtonItem!

	@IBOutlet private weak var datePicker: UIDatePicker!

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "hh:mm a"
		return formatter
	}()
	weak var delegate: TimeSelectionViewControllerDelegate?

	var currentAlarmTime: (hour: Int, minute: Int) {
		get { getCurrentAlarmTime() }
		set {
			updateDatePicker(to: newValue)
		}
	}

	override func viewDidLoad() {
        super.viewDidLoad()

		updateSelectedTimeDisplayLabel()
    }

	private func updateSelectedTimeDisplayLabel() {
		let dateString = TimeSelectionViewController.formatter.string(from: datePicker.date)
		selectedTimeLabel.title = dateString
	}

	private func updateDatePicker(to newValue: (hour: Int, minute: Int)) {
		loadViewIfNeeded()
		let calendar = Calendar.current
		let day = calendar.startOfDay(for: Date())
		guard let dayHour = calendar.date(byAdding: .hour, value: newValue.hour, to: day) else { return }
		guard let dayHourMinute = calendar.date(byAdding: .minute, value: newValue.minute, to: dayHour) else { return }
		datePicker.date = dayHourMinute

		updateSelectedTimeDisplayLabel()
	}

	@IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
		dismiss()
	}

	@IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
		dismiss { [weak self] in
			guard let self = self else { return }
			self.delegate?.timeSelectionVC(self, didSelectTime: self.currentAlarmTime)
		}
	}

	@IBAction func clearAreaTapped(_ sender: UITapGestureRecognizer) {
		dismiss()
	}

	func dismiss(completion: @escaping () -> Void = {}) {
		dismiss(animated: true, completion: completion)
	}

	@IBAction func datePickerUpdated(_ sender: UIDatePicker) {
		updateSelectedTimeDisplayLabel()
	}

	private func getCurrentAlarmTime() -> (hour: Int, minute: Int) {
		let date = datePicker.date
		let calendar = Calendar.current
		let hour = calendar.component(.hour, from: date)
		let minute = calendar.component(.minute, from: date)
		return (hour, minute)
	}
}
