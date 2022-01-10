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
