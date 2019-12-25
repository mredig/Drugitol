//
//  TimeSelectionViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

class TimeSelectionViewController: UIViewController {
	@IBOutlet private var selectedTimeLabel: UIBarButtonItem!

	@IBOutlet private weak var datePicker: UIDatePicker!

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "hh:mm a"
		return formatter
	}()

	override func viewDidLoad() {
        super.viewDidLoad()

		updateSelectedTimeDisplayLabel()
    }

	private func updateSelectedTimeDisplayLabel() {
		let dateString = TimeSelectionViewController.formatter.string(from: datePicker.date)
		selectedTimeLabel.title = dateString
	}

	@IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
		dismiss()
	}

	@IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
		dismiss()
	}

	@IBAction func clearAreaTapped(_ sender: UITapGestureRecognizer) {
		dismiss()
	}

	private func dismiss() {
		dismiss(animated: true)
	}

	@IBAction func datePickerUpdated(_ sender: UIDatePicker) {
		updateSelectedTimeDisplayLabel()
	}
}
