import SwiftUI

@main struct MyApp: App {
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
