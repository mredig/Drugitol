//
//  AlarmView.swift
//  Drugitol
//
//  Created by Michael Redig on 12/16/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

protocol AlarmViewDelegate: AnyObject {
	func alarmViewInvokedEditing(_ alarmView: AlarmView)
	func alarmViewInvokedDeletion(_ alarmView: AlarmView)
}

class AlarmView: UIView {
	@IBOutlet private var contentView: UIView!
	@IBOutlet private weak var label: UILabel!

	var alarmTime: DrugAlarm {
		didSet {
			updateViews()
		}
	}
	weak var delegate: AlarmViewDelegate?

	init(alarmTime: DrugAlarm) {
		self.alarmTime = alarmTime
		super.init(frame: .zero)
		commonInit()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init coder not implemented")
	}

	private func commonInit() {
		let nib = UINib(nibName: "AlarmView", bundle: nil)
		nib.instantiate(withOwner: self, options: nil)

		addSubview(contentView)
		contentView.translatesAutoresizingMaskIntoConstraints = false
		contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
		contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
		contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

		updateViews()
	}

	private func updateViews() {
		label.text = "Every day at \(alarmTime.prettyTimeString)"
	}

	@IBAction func editButtonPressed(_ sender: UIButton) {
		delegate?.alarmViewInvokedEditing(self)
	}

	@IBAction func minusButtonPressed(_ sender: UIButton) {
		delegate?.alarmViewInvokedDeletion(self)
	}
}
