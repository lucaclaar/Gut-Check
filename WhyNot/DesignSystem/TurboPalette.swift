import SwiftUI

enum TurboPalette {
  static func color(for slot: Int) -> Color {
    let colors = [GutTheme.purple, GutTheme.yellow, GutTheme.indigo, GutTheme.orange]
    return colors[max(0, slot) % colors.count]
  }
}
