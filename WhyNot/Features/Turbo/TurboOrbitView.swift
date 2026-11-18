import SwiftUI

struct TurboOrbitView: View {
  let reserve: Double

  private static let gap: CGFloat = 4
  private static let lineWidth: CGFloat = 3
  static let diameterAddition = 2 * (gap + lineWidth)

  private var tint: Color {
    let orangeAmount = min(1, (1 - reserve) / 0.5)
    let redAmount = min(1, max(0, (0.5 - reserve) / 0.4))
    return Color.white.mix(with: .orange, by: orangeAmount)
      .mix(with: .red, by: redAmount)
  }

  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.18), lineWidth: Self.lineWidth)
      Circle().trim(from: 0, to: reserve)
        .stroke(tint, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(-(Self.gap + Self.lineWidth / 2))
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
