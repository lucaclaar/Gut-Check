import SwiftUI

struct TurboBubbleSurface: View {
  let title: String
  let slot: Int
  var diameter: Double = 130
  var large = false
  var interactive = false

  private var color: Color { TurboPalette.color(for: slot) }

  var body: some View {
    Text(title)
      .font(large ? GutTheme.display(30) : .system(.body, design: .rounded).weight(.semibold))
      .foregroundStyle(.white)
      .multilineTextAlignment(.center)
      .lineLimit(3)
      .minimumScaleFactor(0.55)
      .padding(14)
      .frame(width: diameter, height: diameter)
      .glassEffect(.regular.tint(color.opacity(0.40)).interactive(interactive), in: .circle)
  }
}
