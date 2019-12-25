//
//  DefaultsManager.swift
//  Drugitol
//
//  Created by Michael Redig on 12/24/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

class DefaultsManager {
	private static let shared = DefaultsManager()
	private init() {
		migrateDefaults()
	}

	static var defaultsVersion: Int {
		get { shared.defaults.integer(forKey: .defaultsVersionKey) }
		set { shared.defaults.set(newValue, forKey: .defaultsVersionKey) }
	}

	static var lastSelectedDoseIndex: Int {
		get { shared.defaults.integer(forKey: .lastSelectedDoseIndexKey) }
		set { shared.defaults.set(newValue, forKey: .lastSelectedDoseIndexKey) }
	}

	// MARK: - Private utilities
	private func migrateDefaults() {
		if DefaultsManager.defaultsVersion == 0 {
			defaults.set(1, forKey: .defaultsVersionKey)
		}
	}

	fileprivate let defaults = UserDefaults.standard
}

// MARK: - Keys
fileprivate extension String {
	static let defaultsVersionKey = "com.redeggproductions.defaultsVersion"
	static let lastSelectedDoseIndexKey = "com.redeggproductions.defaultsVersion"
}
