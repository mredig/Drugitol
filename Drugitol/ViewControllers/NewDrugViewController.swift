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
		let alarm = drugController.createDrugAlarm(alarmTime: 7 * 60 * 60)
		addAlarmView(for: alarm)
	}
}

extension NewDrugViewController: AlarmViewDelegate {
	func alarmViewInvokedEditing(_ alarmView: AlarmView) {
		performSegue(withIdentifier: "AlarmTimeSegue", sender: nil)
	}

	func alarmViewInvokedDeletion(_ alarmView: AlarmView) {
		removeAlarmView(alarmView)
	}
}
