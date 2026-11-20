import SwiftUI

struct TurboTimerView: View {
  let session: TurboSession

  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.12), lineWidth: 5)
      Circle().trim(from: 0, to: session.remaining / session.duration)
        .stroke(GutTheme.yellow.mix(with: GutTheme.orange, by: min(1, max(0, 1 - session.remaining / 5))),
          style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Text("0:\(session.secondsRemaining, format: .number.precision(.integerLength(2)))")
        .font(GutTheme.display(26)).monospacedDigit().contentTransition(.numericText(countsDown: true))
    }
    .frame(width: 92, height: 92)
    .accessibilityElement(children: .ignore).accessibilityLabel("Round timer")
    .accessibilityValue("\(session.secondsRemaining) seconds remaining")
  }
}
