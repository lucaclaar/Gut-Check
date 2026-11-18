import SwiftUI

struct ModeSelectionView: View {
  let session: ReflectionSession
  let savedTurboDecisions: [SavedTurboDecision]
  let startTurbo: () -> Void

  @AppStorage("hasSeenHomeTip") private var hasSeenHomeTip = false
  @AppStorage("hasDoneCardPractice") private var hasDoneCardPractice = false
  @AppStorage("turboSoundEnabled") private var soundOn = true
  @State private var showTip = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize

  private var recent: [RecentDecision] {
    RecentDecision.latest(reflect: session.savedDecisions, turbo: savedTurboDecisions)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text("Gut Check").font(GutTheme.display(18)).tracking(-0.36)
          Spacer()
          Button("How it works", systemImage: "questionmark", action: showHints)
            .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
            .accessibilityIdentifier("home.help")
          Button("Turbo sounds", systemImage: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
            soundOn.toggle()
          }
          .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
          .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
          .accessibilityValue(soundOn ? "On" : "Off")
          .accessibilityIdentifier("home.turboSound")
        }
        Text("How do you want to decide?").font(GutTheme.display(27)).tracking(-0.54)
          .fixedSize(horizontal: false, vertical: true).padding(.top, 28).padding(.bottom, 47)

        if showTip && typeSize.isAccessibilitySize {
          tip.padding(.bottom, 16)
        }
        Button {
          dismissTip()
          session.start()
        } label: {
          ModeCard(
            title: "Reflect",
            subtitle: "When you don’t have all the options and need time to think.",
            mascot: "MascotStillDoubtful1", isReflect: true)
        }
        .buttonStyle(.plain).accessibilityIdentifier("mode.reflect")
        .overlay(alignment: .topTrailing) {
          if showTip && !typeSize.isAccessibilitySize {
            tip.frame(maxWidth: 190).offset(x: 12, y: -47)
              .transition(.opacity)
          }
        }

        Button {
          dismissTip()
          startTurbo()
        } label: {
          ModeCard(title: "Turbo", subtitle: "Few options to make a quick decision.",
            mascot: "MascotWorstCase3", isReflect: false)
        }
        .buttonStyle(.plain).accessibilityIdentifier("mode.turbo").padding(.top, 14)

        let recent = recent
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

  private var tip: some View {
    TipBubble(text: "New here? Pick Reflect if you have time, Turbo if you don’t.", dismiss: dismissTip)
  }

  private func showHints() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { showTip = true }
    hasDoneCardPractice = false
  }

  private func dismissTip() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { showTip = false }
    hasSeenHomeTip = true
  }
}
