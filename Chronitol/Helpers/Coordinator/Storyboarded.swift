import UIKit

@MainActor
protocol Storyboarded {
	static func instantiate(from storyboard: String) -> Self
}

@MainActor
extension Storyboarded where Self: UIViewController {
	static func instantiate() -> Self {
		instantiate(from: "Main")
	}

	static func instantiate(from storyboard: String) -> Self {
		let fullName = NSStringFromClass(self)

		let className = fullName.components(separatedBy: ".")[1]

		let storyboard = UIStoryboard(name: storyboard, bundle: .main)

		return storyboard.instantiateViewController(withIdentifier: className) as! Self
	}
}
