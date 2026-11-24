import SwiftUI

@main struct MyApp: App {
  @UIApplicationDelegateAdaptor private var appIconDelegate: AppIconApplicationDelegate

  init() {
    ReflectionReminder.shared.activate()
    PhoneWatchLink.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
