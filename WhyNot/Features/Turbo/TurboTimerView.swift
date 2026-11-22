import SwiftUI

/// Seconds left in the round, shown in the navigation bar.
struct TurboTimerView: View {
  let session: TurboSession

  private var urgent: Bool { session.phase == .playing && session.remaining <= 5 }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text("\(session.secondsRemaining)")
        .font(GutTheme.display(30)).monospacedDigit()
        .contentTransition(.numericText(countsDown: true))
      Text("s left")
        .font(.system(.subheadline, design: .rounded).weight(.medium))
        .foregroundStyle(GutTheme.muted)
    }
    .foregroundStyle(urgent ? TurboPalette.danger : .white)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Round timer")
    .accessibilityValue("\(session.secondsRemaining) seconds left")
  }
}

/// The round's time left as a bar that empties from right to left.
struct TurboRoundBar: View {
  let session: TurboSession

  var body: some View {
    GeometryReader { proxy in
      Capsule().fill(.white.opacity(0.1))
        .overlay(alignment: .leading) {
          Capsule()
            .fill(LinearGradient(colors: [TurboPalette.color(for: 0), TurboPalette.color(for: 2)],
              startPoint: .leading, endPoint: .trailing))
            .frame(width: proxy.size.width * session.remaining / session.duration)
        }
    }
    .frame(height: 6)
    .accessibilityHidden(true)
  }
}
