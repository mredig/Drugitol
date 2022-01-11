import UIKit

class LargeTitledNavigationController: UINavigationController {
	override func viewDidLoad() {
		super.viewDidLoad()

		navigationBar.prefersLargeTitles = true
	}
}
