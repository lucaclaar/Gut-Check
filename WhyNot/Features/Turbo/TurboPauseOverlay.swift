import SwiftUI

struct TurboPauseOverlay: View {
  let session: TurboSession
  let isAppSwitcherCover: Bool
  let leave: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      if isAppSwitcherCover {
        MascotView(name: "MascotStillDoubtful1", width: 160, height: 170)
        VStack(spacing: 8) {
          Text("No peeking.").font(GutTheme.display(25))
          Text("I’m helping you decide.")
            .font(.system(.body, design: .rounded)).foregroundStyle(GutTheme.muted)
        }
        .multilineTextAlignment(.center)
      } else if session.phase == .countdown {
        Text("Go with your gut.").font(GutTheme.display(20))
        Text("\(session.countdownNumber)")
          .font(GutTheme.display(110)).foregroundStyle(GutTheme.yellow).monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.countdownNumber)
          .accessibilityLabel("Starting in \(session.countdownNumber)")
      } else {
        MascotView(name: "MascotStillDoubtful1", width: 160, height: 170)
        Text("Round paused.").font(GutTheme.display(25)).multilineTextAlignment(.center)
        GutButton(title: "Resume · 3, 2, 1") { session.resume() }.padding(.top, 16)
          .accessibilityIdentifier("turbo.resume")
        Button("Back to options", action: leave).frame(minHeight: 44)
      }
      Spacer()
    }
    .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { GutBackground() }.ignoresSafeArea()
  }
}
