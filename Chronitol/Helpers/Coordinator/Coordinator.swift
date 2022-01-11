import Foundation
import UIKit

@MainActor
protocol Coordinator {
	var children: [Coordinator] { get }

	func start()
}

@MainActor
protocol NavigationCoordinator: Coordinator {
	var navigationController: UINavigationController { get }
}
