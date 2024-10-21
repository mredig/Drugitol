import Foundation

public extension Array {
	subscript(optional index: Int) -> Element? {
		guard index < count else { return nil }
		return self[index]
	}
}

public extension Collection {
	var hasContent: Bool {
		!isEmpty
	}
}

import Combine
typealias Bag = Set<AnyCancellable>

import UIKit
extension UIView {
	@discardableResult func forAutolayout() -> Self {
		translatesAutoresizingMaskIntoConstraints = false
		return self
	}

	var isVisible: Bool {
		get { !isHidden }
		set {
			let newHidden = !newValue
			guard newHidden != isHidden else { return }
			isHidden = newHidden
		}
	}

	struct ConstraintEdgeToggle {
		var top: Bool
		var bottom: Bool
		var leading: Bool
		var trailing: Bool
	}

}

extension UIView.ConstraintEdgeToggle: ExpressibleByBooleanLiteral {
	init(uniform: Bool) {
		self.init(horizontal: uniform, vertical: uniform)
	}

	init(horizontal: Bool, vertical: Bool) {
		self.top = vertical
		self.bottom = vertical
		self.leading = horizontal
		self.trailing = horizontal
	}

	public init(booleanLiteral: Bool) {
		self.init(uniform: booleanLiteral)
	}
}
