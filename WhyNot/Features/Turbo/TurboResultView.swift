import SwiftUI

/// Where the round ends: the pick, a tie to break, or everything popped.
struct TurboResultView: View {
  let session: TurboSession
  let replay: () -> Void
  let proceed: () -> Void
  let reflect: () -> Void
  @AppStorage("turboSoundEnabled") private var soundEnabled = true
  @Environment(\.scenePhase) private var scenePhase
  @State private var sounds = TurboSounds()
  @State private var playedResult = false

  var body: some View {
    ScrollView {
      Group {
        if session.phase == .tie { tie }
        else if let choice = session.chosen { picked(choice) }
        else { timedOut }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.bottom, 40).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .background(GutBackground())
    .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
    .safeAreaInset(edge: .bottom) {
      if session.phase != .tie {
        VStack(spacing: 14) {
          if session.chosen == nil {
            GutButton(title: "Reflect on it instead", prominent: false, action: reflect)
            GutButton(title: "Try again", action: replay)
              .accessibilityIdentifier("turbo.result.retry")
          } else {
            GutButton(title: "Play again", prominent: false, action: replay)
            GutButton(title: "Continue", action: proceed)
              .accessibilityIdentifier("turbo.result.continue")
          }
        }
        .frame(maxWidth: 500).padding(.horizontal, 24).padding(.bottom, 20)
      }
    }
    .onAppear { session.returnToResult() }
    .task(id: session.phase) {
      guard session.phase != .tie, !playedResult, soundEnabled, scenePhase == .active else { return }
      playedResult = true
      sounds.play(session.chosen == nil ? .timeout : .picked)
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { sounds.stop() } }
    .onDisappear { sounds.stop() }
  }

  private func picked(_ choice: TurboBubble) -> some View {
    VStack(spacing: 0) {
      MascotView(name: "MascotBestCase2", width: 180, height: 150).padding(.top, 28)
      GutEyebrow(title: "YOUR GUT PICKED").multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).padding(.top, 14)
        .fixedSize(horizontal: true, vertical: false)
      TurboLiquidBubble(title: nil, slot: choice.slot, diameter: 112).padding(.top, 16)
      Text(choice.text).font(GutTheme.display(30)).multilineTextAlignment(.center)
        .padding(.top, 14).accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Your gut picked \(choice.text)")
      Text(reason(for: choice))
        .font(.system(.footnote, design: .rounded).weight(.semibold))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.white.opacity(0.08), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
        .padding(.top, 12)
      Text(stats(for: choice))
        .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted)
        .multilineTextAlignment(.center).padding(.top, 12)
    }
  }

  private func reason(for choice: TurboBubble) -> String {
    switch session.outcome {
    case .held: "You held it to pick it"
    case .mostSaves: "Tapped most when time ran out"
    case .tieBreak: "You broke the tie"
    case .lastStanding, nil:
      session.bubbles.contains { $0.taps > 0 } ? "Last one standing" : "You let the others go"
    }
  }

  private func stats(for choice: TurboBubble) -> String {
    let time = "Decided in \(session.elapsed.formatted(.number.precision(.fractionLength(1)))) s"
    guard choice.taps > 0 else { return "\(time) · no taps on it" }
    let taps = "tapped \(choice.taps) \(choice.taps == 1 ? "time" : "times")"
    return "\(time) · \(taps), \(choice.lastSecondSaves) at the last second"
  }

  private var tie: some View {
    let names = session.tiedBubbles.map(\.text)
    return VStack(alignment: .leading, spacing: 14) {
      GutEyebrow(title: "TIME’S UP").padding(.top, 40)
      Text("Too close to call").font(GutTheme.display(27)).accessibilityAddTraits(.isHeader)
      Text("\(names.formatted(.list(type: .and))) were tapped the same number of times. Pick one. No timer this time.")
        .font(.system(.body, design: .rounded)).foregroundStyle(GutTheme.muted)
        .fixedSize(horizontal: false, vertical: true)
      ForEach(session.tiedBubbles) { bubble in
        Button { session.breakTie(bubble.id) } label: {
          Text(bubble.text).font(GutTheme.display(19))
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 22)
            .foregroundStyle(TurboPalette.textColor(for: bubble.slot))
            .background(TurboPalette.color(for: bubble.slot), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Picks \(bubble.text)")
      }
      .padding(.top, 8)
      MascotView(name: "MascotStillDoubtful1", width: 150, height: 160)
        .frame(maxWidth: .infinity).padding(.top, 24)
    }
  }

  private var timedOut: some View {
    VStack(spacing: 0) {
      MascotView(name: "MascotStillDoubtful2", width: 180, height: 190).padding(.top, 28)
      Text("Time’s up!").font(GutTheme.display(27)).padding(.top, 26)
        .accessibilityAddTraits(.isHeader)
      Circle().strokeBorder(GutTheme.muted.opacity(0.65), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
        .frame(width: 150, height: 150)
        .overlay { Text("?").font(GutTheme.display(40)) }
        .padding(.top, 28).accessibilityHidden(true)
      Text("You didn’t tap any of the \(session.bubbles.count) options. Maybe none of them felt right.")
        .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted)
        .multilineTextAlignment(.center).padding(.top, 24)
    }
  }
}
