import OSLog
import UIKit

final class AppIconSceneDelegate: NSObject, UIWindowSceneDelegate {
  private enum Icon: String {
    case eyes = "AppIcon.Eyes"
    case mascots = "AppIcon.Mascots"

    var alternateName: String? { self == .mascots ? "AppIconMascots" : nil }
  }

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GutCheck", category: "AppIcon")
  private var pendingIcon: Icon?
  private var isChangingIcon = false

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    if let shortcut = options.shortcutItem {
      pendingIcon = Icon(rawValue: shortcut.type)
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    Task { applyPendingIcon(in: scene) }
  }

  func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem)
    async -> Bool {
    guard let icon = Icon(rawValue: shortcutItem.type) else { return false }
    pendingIcon = icon
    applyPendingIcon(in: windowScene)
    return true
  }

  private func applyPendingIcon(in scene: UIScene) {
    guard scene.activationState == .foregroundActive, !isChangingIcon, let icon = pendingIcon else { return }
    pendingIcon = nil
    let app = UIApplication.shared
    guard app.supportsAlternateIcons, app.alternateIconName != icon.alternateName else { return }

    isChangingIcon = true
    Task {
      do {
        try await app.setAlternateIconName(icon.alternateName)
      } catch {
        logger.error("Couldn’t change the app icon: \(error.localizedDescription, privacy: .public)")
      }
      isChangingIcon = false
      applyPendingIcon(in: scene)
    }
  }
}
