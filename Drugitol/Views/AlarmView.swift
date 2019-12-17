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
	@IBOutlet private weak var button: UIButton!

	var alarmTime: TimeInterval {
		didSet {
			updateViews()
		}
	}
	weak var delegate: AlarmViewDelegate?

	private let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "h:mm a"
		return formatter
	}()

	init(alarmTime: TimeInterval) {
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
		contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
		contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
		contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		contentView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
	}

	private func updateViews() {
		let time = Date(timeIntervalSince1970: alarmTime)
		label.text = "Every day at \(formatter.string(from: time))"
	}

	@IBAction func buttonPressed(_ sender: UIButton) {
		delegate?.alarmViewInvokedEditing(self)
	}

	@IBAction func minusButtonPressed(_ sender: UIButton) {
		delegate?.alarmViewInvokedDeletion(self)
	}
}
