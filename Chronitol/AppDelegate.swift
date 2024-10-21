import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

	var rootCoordinator: RootCoordinator!

	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
			// Override point for customization after application launch.

			rootCoordinator = RootCoordinator(window: UIWindow(), tabBarController: UITabBarController())
			rootCoordinator.start()
			self.window = rootCoordinator.window

			return true
		}
}
