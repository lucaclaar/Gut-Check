import SwiftUI

struct TurboBubbleSurface: View {
  let title: String
  let slot: Int
  var diameter: Double = 130
  var large = false

  private var color: Color { TurboPalette.color(for: slot) }

  var body: some View {
    Circle()
      .fill(LinearGradient(colors: [color.opacity(0.48), color.opacity(0.18), color.opacity(0.52)],
        startPoint: .topLeading, endPoint: .bottomTrailing))
      .overlay {
        Circle().fill(RadialGradient(colors: [.white.opacity(0.28), .white.opacity(0.06), .clear],
          center: .init(x: 0.28, y: 0.17), startRadius: 0, endRadius: diameter * 0.58))
      }
      .overlay {
        Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.08), color.opacity(0.5)],
          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
      }
      .shadow(color: color.opacity(0.16), radius: 10, y: 5)
      .overlay {
        Text(title).font(large ? GutTheme.display(30) : .system(.body, design: .rounded).weight(.semibold))
          .foregroundStyle(.white).multilineTextAlignment(.center)
          .lineLimit(3).minimumScaleFactor(0.55).padding(14)
      }
      .frame(width: diameter, height: diameter)
  }
}
