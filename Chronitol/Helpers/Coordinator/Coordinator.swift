import Foundation
import UIKit

@MainActor
protocol Coordinator: AnyObject {
	var children: [Coordinator] { get }

	func start()
}

@MainActor
protocol NavigationCoordinator: Coordinator {
	var navigationController: UINavigationController { get }
}
