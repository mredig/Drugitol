import SwiftUI

struct SettingsView: View {
	protocol Coordinator: Chronitol.Coordinator {
		func settingsViewDidPressBackupButton(_ settingsView: SettingsView)
		func settingsViewDidPressImportBackupButton(_ settingsView: SettingsView)
		func settingsViewDidPressResetAndImportBackupButton(_ settingsView: SettingsView)
	}

	let drugController: DrugController
	let coordinator: Coordinator
	@ObservedObject
	var viewModel: ViewModel

	var body: some View {
		VStack {
			backupButton

			importButton

			clearAndImportButton
		}
	}

	private var backupButton: some View {
		Button(
			action: {
				viewModel.areButtonsEnabled = false

				coordinator.settingsViewDidPressBackupButton(self)
			},
			label: {
				Text("Create Backup")
			})
		.disabled(!viewModel.areButtonsEnabled)
	}

	private var importButton: some View {
		Button(
			action: {
				viewModel.areButtonsEnabled = false

				coordinator.settingsViewDidPressImportBackupButton(self)
			},
			label: {
				Text("Import Backup")
			})
		.disabled(!viewModel.areButtonsEnabled)
	}

	private var clearAndImportButton: some View {
		Button(
			action: {
				viewModel.areButtonsEnabled = false

				coordinator.settingsViewDidPressResetAndImportBackupButton(self)
			},
			label: {
				Text("Reset Current Data and Import Backup")
			})
		.disabled(!viewModel.areButtonsEnabled)
	}

	class ViewModel: ObservableObject {
		@Published
		var areButtonsEnabled = true
	}
}
