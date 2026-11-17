import SwiftUI

struct GutBackground: View {
  var asset = "32-15-Glow"
  var origin = CGPoint(x: -120, y: -80)

  var body: some View {
    GeometryReader { proxy in
      GutTheme.background
        .overlay(alignment: .topLeading) {
          // Preserve Figma's 140 pt blur overflow on each side.
          Image(decorative: asset)
            .resizable()
            .frame(width: 660, height: 660)
            .offset(x: origin.x - 140, y: origin.y - 140)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}
