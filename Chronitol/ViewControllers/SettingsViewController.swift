import UIKit

@MainActor
class SettingsViewController: UIViewController, Storyboarded {
	@IBOutlet private weak var exportBackupButton: UIButton!

	var drugController: DrugController!

	@IBAction func exportBackupButtonPressed(_ sender: UIButton) {
		sender.isEnabled = false
		Task {
			let exportPlistData = try await drugController.exportPlistData()
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

			sender.isEnabled = true
		}
	}
}
