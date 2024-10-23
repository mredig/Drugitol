import Logging
import SwiftUI
import SwiftPizzaSnips

class SettingsCoordinator: NavigationCoordinator, ObservableObject {
	var children: [Coordinator] = []

	let navigationController = UINavigationController()

	var rootController: UIViewController { navigationController }
	private var settingsViewController: UIViewController!

	let viewModel = SettingsView.ViewModel()
	let drugController: DrugController

	private var docDelegate: DocumentDelegate?

	let log = Logger(label: "SettingsCoordinator")

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

			viewModel.areButtonsEnabled = true
		}
	}

	func settingsViewDidPressResetAndImportBackupButton(_ settingsView: SettingsView) {
		Task {
			do {
				try await importBackup(withReset: true)
			} catch {
				print("Error \(#function): \(error)")
			}
		}
	}

	func settingsViewDidPressImportBackupButton(_ settingsView: SettingsView) {
		Task {
			do {
				try await importBackup(withReset: false)
			} catch {
				print("Error \(#function): \(error)")
			}
		}
	}

	private func importBackup(withReset flag: Bool) async throws {
		let delegate = DocumentDelegate(
			drugController: drugController,
			beforeOpen: { [drugController] in
				if flag {
					try await drugController.clearDB()
					DefaultsManager.shared.reset(key: .delayedAlarms)
					LocalNotifications.shared.deleteAllReminders()
				}
			},
			onComplete: {
				self.viewModel.areButtonsEnabled = true
				self.docDelegate = nil
			})
		self.docDelegate = delegate

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.propertyList])
		documentPicker.delegate = delegate
		navigationController.present(documentPicker, animated: true)
	}

	private class DocumentDelegate: NSObject, UIDocumentPickerDelegate {
		let beforeOpen: () async throws -> Void
		let onComplete: () -> Void
		let drugController: DrugController
		let log = Logger(label: "DocumentDelegate")

		init(drugController: DrugController, beforeOpen: @escaping () async throws -> Void, onComplete: @escaping () -> Void) {
			self.beforeOpen = beforeOpen
			self.drugController = drugController
			self.onComplete = onComplete
		}

		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			Task {
				defer { onComplete() }

				do {
					guard let backupURL = urls.first else { return }
					guard
						backupURL.startAccessingSecurityScopedResource()
					else { throw SimpleError(message: "Cannot start secure access") }
					defer { backupURL.stopAccessingSecurityScopedResource() }
					let data = try Data(contentsOf: backupURL)
					try await beforeOpen()
					try await drugController.importFromPlistData(data)
				} catch {
					log.error("Error importing backup", metadata: ["error": .stringConvertible(error as CustomStringConvertible)])
				}
			}
			controller.dismiss(animated: true)
		}

		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			defer { onComplete() }
			controller.dismiss(animated: true)
		}
	}
}

