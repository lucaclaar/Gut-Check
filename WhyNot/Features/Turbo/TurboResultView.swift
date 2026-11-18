import SwiftUI

struct TurboResultView: View {
  let session: TurboSession
  let replay: () -> Void
  let proceed: () -> Void
  let reflect: () -> Void
  @AppStorage("turboSoundEnabled") private var soundEnabled = true
  @Environment(\.scenePhase) private var scenePhase
  @State private var sounds = TurboSounds()
  @State private var playedResult = false

  private var timedOut: Bool { session.chosen == nil }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        MascotView(name: timedOut ? "MascotStillDoubtful1" : "MascotBestCase2", width: 180,
          height: timedOut ? 190 : 158).padding(.top, 38)
        Text(timedOut ? "Time’s up!" : "Your gut picked…")
          .font(GutTheme.display(27)).multilineTextAlignment(.center)
          .padding(.top, timedOut ? 30 : 44)
        if let choice = session.chosen {
          TurboBubbleSurface(title: choice.text, slot: choice.slot, diameter: 180, large: true)
            .padding(.top, 36).accessibilityLabel("Chosen option: \(choice.text)")
          Text("Saved \(choice.rescues) \(choice.rescues == 1 ? "time" : "times") · decided in \(Int(session.elapsed.rounded())) s")
            .font(.footnote).foregroundStyle(GutTheme.muted).padding(.top, 28)
        } else {
          Circle().strokeBorder(GutTheme.muted.opacity(0.65), style: StrokeStyle(lineWidth: 3, dash: [10, 10]))
            .frame(width: 180, height: 180)
            .overlay { Text("?").font(GutTheme.display(34)) }
            .padding(.top, 36).accessibilityHidden(true)
          Text("No option was chosen. Maybe none of them felt right.")
            .font(.footnote).foregroundStyle(GutTheme.muted).multilineTextAlignment(.center)
            .padding(.top, 28)
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.bottom, 40).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .background(GutBackground(origin: CGPoint(x: 172, y: 580)))
    .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 14) {
        GutButton(title: timedOut ? "Reflect on it instead" : "Play again", prominent: false,
          action: timedOut ? reflect : replay)
        GutButton(title: timedOut ? "Try again" : "Continue", action: timedOut ? replay : proceed)
          .accessibilityIdentifier("turbo.result.continue")
      }.padding(.horizontal, 24).padding(.bottom, 20)
    }
    .onAppear { session.returnToResult() }
    .task {
      guard !playedResult, soundEnabled, scenePhase == .active else { return }
      playedResult = true
      sounds.play(timedOut ? .timeout : .picked)
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { sounds.stop() } }
    .onDisappear { sounds.stop() }
  }
}
