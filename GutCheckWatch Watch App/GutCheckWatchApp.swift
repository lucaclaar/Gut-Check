import CoreText
import SwiftUI

@main
struct GutCheckWatchApp: App {
  init() {
    // Unbounded is the app's heading font; watchOS has no UIAppFonts, so register it at launch.
    if let url = Bundle.main.url(forResource: "Unbounded", withExtension: "ttf") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    WatchLink.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(link: WatchLink.shared)
    }
    .backgroundTask(.watchConnectivity) {
      await WatchLink.shared.handleBackgroundConnectivity()
    }
  }
}
