import SwiftUI

struct ModeSelectionView: View {
  let session: ReflectionSession
  @AppStorage("hasSeenHomeTip") private var hasSeenHomeTip = false
  @AppStorage("hasDoneCardPractice") private var hasDoneCardPractice = false
  /// App sound preference. Playback is not implemented yet; it must also respect the
  /// Ring/Silent switch (use the .ambient audio session category).
  @AppStorage("soundOn") private var soundOn = true
  @State private var showTip = false
  private var recent: [SavedDecision] { Array(session.savedDecisions.suffix(2).reversed()) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text("Gut Check").font(GutTheme.display(18)).tracking(-0.36)
          Spacer()
          Button("How it works", systemImage: "questionmark", action: showHints)
            .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
          Button("Sound", systemImage: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
            soundOn.toggle()
          }
          .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
          .contentTransition(.symbolEffect(.replace))
          .accessibilityValue(soundOn ? "On" : "Off")
          .accessibilityHint(soundOn ? "Double-tap to mute" : "Double-tap to turn on")
        }
        Text("How do you want to decide?").font(GutTheme.display(27)).tracking(-0.54)
          .fixedSize(horizontal: false, vertical: true).padding(.top, 28).padding(.bottom, 47)
        Button(action: startReflect) {
          ModeCard(
            title: "Reflect",
            subtitle: "When you don’t have all the options and need time to think.",
            mascot: "MascotStillDoubtful1", isReflect: true)
        }
        .buttonStyle(.plain).accessibilityIdentifier("mode.reflect")
        .overlay(alignment: .topTrailing) {
          if showTip {
            TipBubble(text: "New here? Pick Reflect if you have time, Turbo if you don’t.") {
              dismissTip()
            }
            .frame(maxWidth: 190).offset(x: 12, y: -47)
            .transition(.opacity)
          }
        }
        ModeCard(
          title: "Turbo", subtitle: "Few options to make a quick decision.",
          mascot: "MascotWorstCase3", isReflect: false
        )
        .accessibilityLabel("Turbo, coming soon").padding(.top, 14)
        if !recent.isEmpty {
          GutEyebrow(title: "RECENT").padding(.top, 33).padding(.bottom, 10)
          VStack(spacing: 8) {
            ForEach(recent) { RecentDecisionRow(decision: $0) }
          }
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 40)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).background(GutBackground()).toolbar(.hidden, for: .navigationBar)
    .onAppear { if !hasSeenHomeTip { showTip = true } }
  }
  private func startReflect() {
    dismissTip()
    session.start()
  }
  /// Help brings every hint back: the bubble now, the practice card on the next Reflect.
  private func showHints() {
    withAnimation { showTip = true }
    hasDoneCardPractice = false
  }
  private func dismissTip() {
    withAnimation { showTip = false }
    hasSeenHomeTip = true
  }
}

/// Mascot speech bubble used for first-time tips. Tapping it dismisses it.
struct TipBubble: View {
  let text: String
  let dismiss: () -> Void
  var body: some View {
    Button(action: dismiss) {
      Text(text).font(.system(.subheadline, design: .rounded).weight(.medium))
        .foregroundStyle(GutTheme.ink).multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
          .white,
          in: UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 6, bottomTrailingRadius: 22,
            topTrailingRadius: 22))
    }
    .buttonStyle(.plain)
    .accessibilityHint("Double-tap to dismiss")
  }
}
