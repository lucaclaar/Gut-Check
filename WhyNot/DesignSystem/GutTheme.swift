import SwiftUI

enum GutTheme {
  static let background = Color("GutBackground")
  static let muted = Color("GutMuted")
  static let ink = Color("GutInk")
  static let purple = Color("GutPurple")
  static let yellow = Color("GutYellow")
  static let orange = Color("GutOrange")
  static let indigo = Color("GutIndigo")

  static func display(_ size: Double = 27) -> Font {
    .custom("Unbounded-Regular_SemiBold", size: size, relativeTo: .title)
  }
}
