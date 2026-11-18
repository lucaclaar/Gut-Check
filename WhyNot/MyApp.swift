import SwiftUI

@main struct MyApp: App {
    init() {
        PhoneWatchLink.shared.activate() 
      }
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
