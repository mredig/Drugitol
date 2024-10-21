import UIKit

@MainActor
class TimeSelectionViewController: UIViewController, Storyboarded {
	@IBOutlet private var selectedTimeLabel: UIBarButtonItem!

	@IBOutlet private weak var datePicker: UIDatePicker!

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "hh:mm a"
		return formatter
	}()
	/// Only runs this closure in the event that the user confirms their selection with the "done" button
	var successCompletion: SuccessCompletionHandler?

	typealias AlarmTimeComponents = (hour: Int, minute: Int)
	typealias SuccessCompletionHandler = (AlarmTimeComponents) -> Void

	var selectedAlarmTime: AlarmTimeComponents {
		get { getCurrentAlarmTime() }
		set { updateDatePicker(to: newValue) }
	}

	override func viewDidLoad() {
        super.viewDidLoad()

		updateSelectedTimeDisplayLabel()

		if #available(iOS 13.4, *) {
			datePicker.preferredDatePickerStyle = .wheels
		}
    }

	private func updateSelectedTimeDisplayLabel() {
		let dateString = TimeSelectionViewController.formatter.string(from: datePicker.date)
		selectedTimeLabel.title = dateString
	}

	private func updateDatePicker(to newValue: AlarmTimeComponents) {
		loadViewIfNeeded()
		let converter = AlarmNumberConverter(alarmHour: newValue.hour, alarmMinute: newValue.minute)
		datePicker.date = converter.date

		updateSelectedTimeDisplayLabel()
	}

	@IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
		dismiss()
	}

	@IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
		dismiss { [weak self] in
			guard let self = self else { return }
			self.successCompletion?(self.selectedAlarmTime)
		}
	}

	@IBAction func clearAreaTapped(_ sender: UITapGestureRecognizer) {
		dismiss()
	}

	func dismiss(completion: @escaping () -> Void = {}) {
		dismiss(animated: true, completion: completion)
	}

	@IBAction func datePickerUpdated(_ sender: UIDatePicker) {
		updateSelectedTimeDisplayLabel()
	}

	private func getCurrentAlarmTime() -> AlarmTimeComponents {
		let date = datePicker.date
		let calendar = Calendar.current
		let hour = calendar.component(.hour, from: date)
		let minute = calendar.component(.minute, from: date)
		return (hour, minute)
	}
}
