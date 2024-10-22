import SwiftUI

class SettingsCoordinator: NavigationCoordinator, ObservableObject {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()

	var rootController: UIViewController { navigationController }
	private var settingsViewController: UIViewController!

	let viewModel = SettingsView.ViewModel()
	let drugController: DrugController

	@Published
	private var isExportEnabled = true

	init(drugController: DrugController) {
		self.drugController = drugController

		let settingsView = SettingsView(
			drugController: drugController,
			coordinator: self,
			viewModel: viewModel)
		self.settingsViewController = UIHostingController(rootView: settingsView)
	}

	func start() {
		let tabBarItem = UITabBarItem(title: "Settings", image: UIImage(named: "setting-simple"), selectedImage: nil)
		navigationController.tabBarItem = tabBarItem

		navigationController.pushViewController(settingsViewController, animated: false)
	}
}

extension SettingsCoordinator: SettingsView.Coordinator {
	func settingsViewDidPressBackupButton(_ settingsView: SettingsView) {
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
			navigationController.present(sheet, animated: true)

			viewModel.isExportEnabled = true
		}
	}
}
