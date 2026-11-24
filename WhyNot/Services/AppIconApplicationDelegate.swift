import UIKit

final class AppIconApplicationDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
    configurationForConnecting session: UISceneSession,
    options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
    if session.role == .windowApplication {
      configuration.delegateClass = AppIconSceneDelegate.self
    }
    return configuration
  }
}
