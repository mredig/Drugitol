//
//  NewDrugViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

class NewDrugViewController: UIViewController {

	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var alarmListStackView: UIStackView!
	@IBOutlet private weak var isActiveSwitch: UISwitch!


	let drugController = DrugController(context: .mainContext)

	var entry: DrugEntry? {
		didSet {
			updateViews()
		}
	}

	private var removedAlarms: [DrugAlarm] = []

	override func viewDidLoad() {
        super.viewDidLoad()
    }

	private func updateViews() {
		loadViewIfNeeded()
		guard let entry = entry else { return }
		nameTextField.text = entry.name
		isActiveSwitch.isOn = entry.isActive
		entry.drugAlarms.forEach {
			addAlarmView(for: $0)
		}
	}

	private func addAlarmView(for alarm: DrugAlarm) {
		let alarmView = AlarmView(alarmTime: alarm)
		alarmView.delegate = self
		alarmListStackView.addArrangedSubview(alarmView)
	}

	private func removeAlarmView(_ alarmView: AlarmView) {
		alarmView.removeFromSuperview()
		removedAlarms.append(alarmView.alarmTime)
	}

	@IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
		guard let name = nameTextField.text else { return }

		let entry = self.entry ?? drugController.createDrugEntry(named: name)

		let alarms = alarmListStackView.arrangedSubviews.compactMap { ($0 as? AlarmView)?.alarmTime }
		drugController.updateDrugEntry(entry, name: name, isActive: isActiveSwitch.isOn, alarms: alarms)
		removedAlarms.forEach { drugController.removeAlarmFromEntry(entry, alarm: $0) }

		navigationController?.popViewController(animated: true)
	}

	@IBAction func plusButtonPressed(_ sender: UIButton) {
		let alarm = drugController.createDrugAlarm(alarmHour: 7, alarmMinute: 0)
		addAlarmView(for: alarm)
	}

	private func presentAlarmTimePicker(for alarmView: AlarmView) {
		guard let alarmTimePickerVC = storyboard?
			.instantiateViewController(withIdentifier: "TimeSelectionViewController")
			as? TimeSelectionViewController else { return }
		let alarm = alarmView.alarmTime
		alarmTimePickerVC.modalPresentationStyle = .overFullScreen
		alarmTimePickerVC.selectedAlarmTime = (alarm.alarmHour, alarm.alarmMinute)
		alarmTimePickerVC.successCompletion = { [weak self] alarmComponents in
			self?.drugController.updateDrugAlarm(alarm, alarmHour: alarmComponents.hour, alarmMinute: alarmComponents.minute)
			alarmView.alarmTime = alarm
		}

		present(alarmTimePickerVC, animated: true)
	}
}

extension NewDrugViewController: AlarmViewDelegate {
	func alarmViewInvokedEditing(_ alarmView: AlarmView) {
		presentAlarmTimePicker(for: alarmView)
	}

	func alarmViewInvokedDeletion(_ alarmView: AlarmView) {
		removeAlarmView(alarmView)
	}
}
