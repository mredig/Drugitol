import UIKit

struct DrugSelectionConfiguration: UIContentConfiguration, Hashable {
	var text: String?

	func makeContentView() -> UIView & UIContentView {
		DrugSelectionView(configuration: self)
	}

	func updated(for state: UIConfigurationState) -> DrugSelectionConfiguration { self }
}

class DrugSelectionView: UIView, UIContentView {
	private let label = UILabel().forAutolayout()

	typealias Config = DrugSelectionConfiguration
	private var appliedConfig: Config!
	var configuration: UIContentConfiguration {
		get { appliedConfig }
		set {
			guard let newConfig = newValue as? Config else { return }
			apply(configuration: newConfig)
		}
	}

	init(configuration: Config) {
		super.init(frame: .zero)
		commonInit()
		apply(configuration: configuration)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func commonInit() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		addSubview(label)
		constraints += constrain(label, inset: NSDirectionalEdgeInsets(horizontal: 16, vertical: 8))
		constraints += [
			widthAnchor.constraint(equalToConstant: 200).withPriority(.required - 1)
		]

		label.setContentHuggingPriority(.required, for: .horizontal)
		label.setContentCompressionResistancePriority(.required, for: .horizontal)
	}

	private func apply(configuration: Config) {
		guard appliedConfig != configuration else { return }
		appliedConfig = configuration

		label.text = configuration.text
	}
}

