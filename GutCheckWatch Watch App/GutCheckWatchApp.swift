import SwiftUI

@main
struct GutCheckWatch_Watch_AppApp: App {
    init() {
       WatchLink.shared.activate()  // start the connection when the app launches
     }
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
