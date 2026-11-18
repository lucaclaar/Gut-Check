import SwiftUI

@main
struct GutCheckWatchApp: App {
  init() { WatchLink.shared.activate() }

  var body: some Scene {
    WindowGroup {
      ContentView(link: WatchLink.shared)
    }
    .backgroundTask(.watchConnectivity) {
      await WatchLink.shared.handleBackgroundConnectivity()
    }
  }
}
