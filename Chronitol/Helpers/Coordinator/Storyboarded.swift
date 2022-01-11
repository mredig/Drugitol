import UIKit

@MainActor
protocol Storyboarded {
	static func instantiate() -> Self
}

@MainActor
extension Storyboarded where Self: UIViewController {
	static func instantiate() -> Self {
		let fullName = NSStringFromClass(self)

		let className = fullName.components(separatedBy: ".")[1]

		let storyboard = UIStoryboard(name: "Main", bundle: .main)

		return storyboard.instantiateViewController(withIdentifier: className) as! Self
	}
}
