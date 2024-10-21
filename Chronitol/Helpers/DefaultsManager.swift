import Foundation

class DefaultsManager {
	private static let shared = DefaultsManager()

	private init() {
		migrateDefaults()
	}

	var defaultsVersion: Int {
		get { defaults.integer(forKey: .defaultsVersionKey) }
		set { defaults.set(newValue, forKey: .defaultsVersionKey) }
	}

	static var lastSelectedDoseIndex: Int {
		get { shared.defaults.integer(forKey: .lastSelectedDoseIndexKey) }
		set { shared.defaults.set(newValue, forKey: .lastSelectedDoseIndexKey) }
	}

	// MARK: - Private utilities
	private func migrateDefaults() {
		if defaultsVersion == 0 {
			defaults.set(1, forKey: .defaultsVersionKey)
		}
	}

	fileprivate let defaults = UserDefaults.standard
}

// MARK: - Keys
fileprivate extension String {
	static let defaultsVersionKey = "com.redeggproductions.defaultsVersion"
	static let lastSelectedDoseIndexKey = "com.redeggproductions.lastSelectedDoseIndex"
}
