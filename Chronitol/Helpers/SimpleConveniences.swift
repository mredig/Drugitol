//
//  SimpleConveniences.swift
//  Chronitol
//
//  Created by Michael Redig on 1/9/22.
//  Copyright © 2022 Red_Egg Productions. All rights reserved.
//

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

	@discardableResult func constrain(
		subview: UIView,
		directionalInset inset: NSDirectionalEdgeInsets = .zero,
		safeArea: ConstraintEdgeToggle = false,
		createConstraintsFor createConstraints: ConstraintEdgeToggle = true,
		activate: Bool = true) -> [NSLayoutConstraint] {

		var constraints: [NSLayoutConstraint] = []

		guard subview.isDescendant(of: self) else {
			print("Need to add subview: \(subview) to parent: \(self) first.")
			return constraints
		}

		defer {
			if activate {
				NSLayoutConstraint.activate(constraints)
			}
		}

		subview.forAutolayout()

		let topAnchor = safeArea.top ? self.safeAreaLayoutGuide.topAnchor : self.topAnchor
		let bottomAnchor = safeArea.bottom ? self.safeAreaLayoutGuide.bottomAnchor : self.bottomAnchor
		let leadingAnchor = safeArea.leading ? self.safeAreaLayoutGuide.leadingAnchor : self.leadingAnchor
		let trailingAnchor = safeArea.trailing ? self.safeAreaLayoutGuide.trailingAnchor : self.trailingAnchor

		if createConstraints.top { constraints.append(subview.topAnchor.constraint(equalTo: topAnchor, constant: inset.top)) }
		if createConstraints.leading { constraints.append(subview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset.leading)) }
		if createConstraints.bottom { constraints.append(bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: inset.bottom)) }
		if createConstraints.trailing { constraints.append(trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: inset.trailing)) }

		return constraints
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

extension NSDirectionalEdgeInsets: Hashable, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
	init(_ edgeInsets: UIEdgeInsets) {
		self.init(top: edgeInsets.top, leading: edgeInsets.left, bottom: edgeInsets.bottom, trailing: edgeInsets.right)
	}

	init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
		self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
	}

	init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
		self.init()
		self.top = top
		self.leading = leading
		self.trailing = trailing
		self.bottom = bottom
	}

	init(uniform: CGFloat = 0) {
		self.init(horizontal: uniform, vertical: uniform)
	}

	public init(floatLiteral value: Double) {
		self.init(uniform: CGFloat(value))
	}

	public init(integerLiteral value: Int) {
		self.init(uniform: CGFloat(value))
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(top)
		hasher.combine(bottom)
		hasher.combine(trailing)
		hasher.combine(leading)
	}
}

extension NSLayoutConstraint {
	func withPriority(_ priority: UILayoutPriority) -> Self {
		self.priority = priority
		return self
	}
}
