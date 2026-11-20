import SwiftUI

/// Covers the round while it can't be played: the app-switcher privacy cover,
/// the 3-2-1 countdown, and the paused round with its choices.
struct TurboPauseOverlay: View {
  let session: TurboSession
  let isAppSwitcherCover: Bool
  let restart: () -> Void
  let saveForLater: () -> Void
  let discard: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if isAppSwitcherCover {
      cover {
        MascotView(name: "MascotStillDoubtful1", width: 160, height: 170)
        Text("No peeking.").font(GutTheme.display(25))
        Text("I’m helping you decide.").foregroundStyle(GutTheme.muted)
      }
    } else if session.phase == .countdown {
      cover {
        Text("Go with your gut.").font(GutTheme.display(20))
        Text("\(session.countdownNumber)")
          .font(GutTheme.display(110)).foregroundStyle(GutTheme.yellow).monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.countdownNumber)
          .accessibilityLabel("Starting in \(session.countdownNumber)")
      }
    } else {
      paused
    }
  }

  private func cover(@ViewBuilder _ content: () -> some View) -> some View {
    VStack(spacing: 16) { content() }
      .multilineTextAlignment(.center)
      .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background { GutBackground() }.ignoresSafeArea()
  }

  /// The round stays visible but dimmed behind the choices, like the design.
  private var paused: some View {
    ZStack(alignment: .bottom) {
      Rectangle().fill(.black.opacity(0.55)).background(.ultraThinMaterial)
        .ignoresSafeArea()
        .onTapGesture { session.resume() }
        .accessibilityHidden(true)
      TurboChoicePanel(title: "Paused",
        message: "Timers are frozen with \(session.secondsRemaining) s left. Nothing pops while you’re here.",
        actions: [
          .init(title: "Resume", kind: .prominent) { session.resume() },
          .init(title: "Start over with new timers", perform: restart),
          .init(title: "Save for later", perform: saveForLater),
          .init(title: "Discard this decision", kind: .destructive, perform: discard),
        ])
        .glassEffect(.regular, in: .rect(cornerRadius: 38))
        .padding(.horizontal, 8).padding(.bottom, 8)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("turbo.paused")
    }
  }
}
