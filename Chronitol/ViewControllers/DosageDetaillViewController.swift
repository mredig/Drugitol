//
//  DosageCreationViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/22/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

@MainActor
protocol DosageDetailViewControllerDelegate: AnyObject {
	func dosageDetailVCDidFinish(_ dosageDetailVC: DosageDetailViewController)
}

@MainActor
class DosageDetailViewController: UIViewController, Storyboarded {
	@IBOutlet private var datePicker: UIDatePicker!
	@IBOutlet private var selectedTimeDisplayLabel: UIBarButtonItem!

	var drugController: DrugController?
	var doseEntry: DoseEntry? {
		didSet {
			updateViews()
		}
	}
	weak var delegate: DosageDetailViewControllerDelegate?

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "MM/dd hh:mm a"
		return formatter
	}()

	override func viewDidLoad() {
		super.viewDidLoad()
		updateViews()

		if #available(iOS 13.4, *) {
			datePicker.preferredDatePickerStyle = .wheels
		}
	}

	private func updateViews() {
		guard isViewLoaded else { return }
		guard let doseEntry = doseEntry, let timestamp = doseEntry.timestamp else { return }
		datePicker.date = timestamp

		updateSelectedTimeDisplayLabel()
	}

	private func updateSelectedTimeDisplayLabel() {
		let dateString = DosageDetailViewController.formatter.string(from: datePicker.date)
		selectedTimeDisplayLabel.title = dateString
	}

	func dismiss(completion: @escaping () -> Void = {}) {
		dismiss(animated: true, completion: completion)
	}

	@IBAction func cancelGesturePressed(_ sender: UITapGestureRecognizer) {
		dismiss()
	}

	@IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
		dismiss()
	}

	@IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
		guard let doseEntry = doseEntry else { return }
		drugController?.updateDoseEntry(doseEntry, timestamp: datePicker.date)
		dismiss { [weak self] in
			guard let self = self else { return }
			self.delegate?.dosageDetailVCDidFinish(self)
		}
	}

	@IBAction func datePickerUpdated(_ sender: UIDatePicker) {
		updateSelectedTimeDisplayLabel()
	}
}
