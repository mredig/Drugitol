//
//  DosageCreationViewController.swift
//  Drugitol
//
//  Created by Michael Redig on 12/22/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

//protocol DosageCreationViewControllerDelegate {
//	<#requirements#>
//}

class DosageCreationViewController: UIViewController {
	@IBOutlet var datePicker: UIDatePicker!
	@IBOutlet var selectedTimeDisplayLabel: UIBarButtonItem!

	@IBAction func cancelGesturePressed(_ sender: UITapGestureRecognizer) {
		cancel()
	}

	@IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
		cancel()
	}

	func cancel() {
		dismiss(animated: true)
	}

	@IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
		let testVC = UIViewController()
		present(testVC, animated: true)
	}

	@IBAction func datePickerUpdated(_ sender: UIDatePicker) {
	}
}
