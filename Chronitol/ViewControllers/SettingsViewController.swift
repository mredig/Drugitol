//
//  SettingsViewController.swift
//  Chronitol
//
//  Created by Michael Redig on 1/2/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

import UIKit

@MainActor
class SettingsViewController: UIViewController {
	@IBOutlet private weak var exportBackupButton: UIButton!

	let drugController = DrugController(context: .mainContext)

	@IBAction func exportBackupButtonPressed(_ sender: UIButton) {
		let exportPlistData = drugController.exportPlistData()
		let url = URL(fileURLWithPath: NSTemporaryDirectory())
			.appendingPathComponent("drugitolbackup")
			.appendingPathExtension("plist")

		do {
			try exportPlistData.write(to: url)
		} catch {
			NSLog("Failed writing plist to file: \(error)")
		}

		let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
		sheet.completionWithItemsHandler = { (_, _, _, error) in
			if let error = error {
				print("Error completing share sheet: \(error)")
			}
			do {
				try FileManager.default.removeItem(at: url)
			} catch {
				NSLog("Error deleting temp file: \(error)")
			}
		}
		present(sheet, animated: true)
	}
}
