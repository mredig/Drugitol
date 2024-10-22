import SwiftUI

struct SettingsView: View {
	protocol Coordinator: Chronitol.Coordinator {
		func settingsViewDidPressBackupButton(_ settingsView: SettingsView)
	}

	let drugController: DrugController
	let coordinator: Coordinator
	@ObservedObject
	var viewModel: ViewModel

	var body: some View {
		VStack {
			backupButton
		}
	}

	private var backupButton: some View {
		Button(
			action: {
				viewModel.isExportEnabled = false

				coordinator.settingsViewDidPressBackupButton(self)
			},
			label: {
				Text("Create Backup")
			})
		.disabled(!viewModel.isExportEnabled)
	}

	class ViewModel: ObservableObject {
		@Published
		var isExportEnabled = true
	}
}
