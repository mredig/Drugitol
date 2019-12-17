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

	let drugController = DrugController(context: .mainContext)

	var entry: DrugEntry? {
		didSet {
			updateViews()
		}
	}

	override func viewDidLoad() {
        super.viewDidLoad()
    }

	private func updateViews() {
		loadViewIfNeeded()
		guard let entry = entry else { return }
		nameTextField.text = entry.name
		entry.drugAlarms.forEach {
			let alarmView = AlarmView(alarmTime: $0)
			alarmListStackView.addArrangedSubview(alarmView)
		}
	}

	@IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
		guard let name = nameTextField.text else { return }

		let alarms = alarmListStackView.arrangedSubviews.compactMap { ($0 as? AlarmView)?.alarmTime }

		if let entry = entry {
			drugController.updateDrugEntry(entry, name: name, alarms: alarms)
		} else {
			let entry = drugController.createDrugEntry(named: name)
			drugController.updateDrugEntry(entry, name: name, alarms: alarms)
		}

		navigationController?.popViewController(animated: true)
	}

	@IBAction func plusButtonPressed(_ sender: UIButton) {
		let alarm = drugController.createDrugAlarm(alarmTime: 7 * 60 * 60)
		let alarmView = AlarmView(alarmTime: alarm)
		alarmListStackView.addArrangedSubview(alarmView)
	}
}
