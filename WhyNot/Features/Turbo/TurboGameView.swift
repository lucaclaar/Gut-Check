import SwiftUI

struct TurboGameView: View {
  let session: TurboSession
  let finish: () -> Void
  let restart: () -> Void
  let saveForLater: () -> Void
  let discard: () -> Void
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("turboSoundEnabled") private var soundEnabled = true
  @State private var sounds = TurboSounds()
  @State private var nextPulse = 0.0
  @State private var resumeOnActivation = false

  private var covered: Bool { scenePhase != .active || session.phase == .paused || session.phase == .countdown }
  private var activeCountdown: Int? {
    scenePhase == .active && session.phase == .countdown ? session.countdownNumber : nil
  }
  private var poppedCount: Int { session.bubbles.count { $0.isPopped && !$0.isDiscarded } }
  private var roundOver: Bool {
    session.phase == .picked || session.phase == .timedOut || session.phase == .tie
  }

  var body: some View {
    gameSurface.background { hapticFeedback }
      .task { if soundEnabled { sounds.load() } }
      .task(id: scenePhase == .active ? session.phase : nil, tickRound)
      .onChange(of: scenePhase, initial: true) { _, phase in updateScene(phase) }
      .onChange(of: session.phase) { _, phase in
        if phase == .paused { sounds.stop() }
        if phase == .countdown && session.elapsed == 0 { nextPulse = 0 }
      }
      .onChange(of: activeCountdown, initial: true) { _, number in
        if number != nil { play(.count) }
      }
      .onChange(of: session.bubbles.map(\.rescues)) { previous, current in
        if let slot = current.indices.first(where: { previous.indices.contains($0) && current[$0] > previous[$0] }) {
          play(.tap, rate: 0.88 + Float(slot) * 0.075)
        }
      }
      .onChange(of: session.activeBubbles.count) { previous, current in
        if current < previous && session.phase == .playing { play(.burst) }
      }
      .onChange(of: session.activeBubbles.filter(session.isAboutToPop).map(\.text)) { previous, current in
        if let name = current.first(where: { !previous.contains($0) }) {
          AccessibilityNotification.Announcement("\(name) is about to pop").post()
        }
      }
      .onDisappear { session.pause(); sounds.stop() }
  }

  private var gameSurface: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        TurboRoundBar(session: session).padding(.top, 10)
        Text(instruction)
          .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted)
          .multilineTextAlignment(.center).padding(.top, 12)
        TurboBubbleArena(session: session)
          .frame(height: max(220, proxy.size.height - 60))
          .padding(.top, 6)
      }
      .frame(maxWidth: 500).frame(maxWidth: .infinity)
      .allowsHitTesting(!covered)
      .accessibilityHidden(covered)
    }
    .padding(.horizontal, 24)
    .background(GutBackground())
    .overlay {
      if covered {
        TurboPauseOverlay(session: session, isAppSwitcherCover: scenePhase != .active,
          restart: restart, saveForLater: saveForLater, discard: discard)
      }
    }
    .navigationBarBackButtonHidden()
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarVisibility(scenePhase == .active ? .automatic : .hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Back", systemImage: "chevron.left") { session.pause() }
          .labelStyle(.iconOnly).disabled(covered)
          .accessibilityHint("Pauses the round")
          .accessibilityIdentifier("turbo.back")
      }
      ToolbarItem(placement: .principal) {
        TurboTimerView(session: session).opacity(session.phase == .playing ? 1 : 0.5)
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button(soundEnabled ? "Mute Turbo sounds" : "Turn Turbo sounds on",
          systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill") {
          soundEnabled.toggle()
          if soundEnabled { play(.tap) } else { sounds.stop() }
        }
        .labelStyle(.iconOnly).accessibilityIdentifier("turbo.sound")
        Button("Pause round", systemImage: "pause.fill") { session.pause() }
          .labelStyle(.iconOnly).disabled(covered)
          .accessibilityIdentifier("turbo.pause")
      }
    }
  }

  private var hapticFeedback: some View {
    Color.clear
      .sensoryFeedback(.selection, trigger: activeCountdown) { _, number in number != nil }
      .sensoryFeedback(trigger: session.phase, phaseFeedback)
      .sensoryFeedback(.impact(weight: .medium, intensity: 0.75), trigger: poppedCount) { previous, current in
        current > previous && session.phase == .playing && scenePhase == .active
      }
      .sensoryFeedback(trigger: session.secondsRemaining, clockFeedback)
      .accessibilityHidden(true)
      .allowsHitTesting(false)
  }

  private func phaseFeedback(_ previous: TurboPhase, _ phase: TurboPhase) -> SensoryFeedback? {
    guard scenePhase == .active else { return nil }
    switch phase {
    case .playing where previous == .countdown: return .impact(weight: .medium)
    case .picked: return .success
    case .timedOut: return .warning
    case .tie: return .selection
    default: return nil
    }
  }

  private func clockFeedback(_ previous: Int, _ current: Int) -> SensoryFeedback? {
    guard session.phase == .playing, scenePhase == .active,
      (1...3).contains(current), current < previous else { return nil }
    return .impact(flexibility: .soft, intensity: 0.25 + 0.18 * Double(3 - current))
  }

  private func tickRound() async {
    guard scenePhase == .active else { return }
    if roundOver {
      do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
      finish()
      return
    }
    while !Task.isCancelled && scenePhase == .active
      && (session.phase == .playing || session.phase == .countdown) {
      session.tick()
      pulseIfNeeded()
      do { try await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 16)) } catch { return }
    }
  }

  private func updateScene(_ phase: ScenePhase) {
    if phase == .active {
      if resumeOnActivation {
        resumeOnActivation = false
        session.resume()
      }
    } else {
      if session.phase == .playing || session.phase == .countdown {
        resumeOnActivation = true
        session.pause()
      }
      sounds.stop()
    }
  }

  private var instruction: String {
    if session.activeBubbles.contains(where: session.isAboutToPop) { return "Tap to save it before it pops." }
    return "Tap to save · Flick to let go · Hold to pick"
  }

  private func pulseIfNeeded() {
    guard session.phase == .playing, session.elapsed >= nextPulse else { return }
    let pressure = max(1 - session.minimumReserve, session.urgency)
    guard pressure >= 0.6 || session.remaining <= 3 else { return }
    nextPulse = session.elapsed + 0.94 - 0.68 * pressure
    play(.pulse, rate: Float(1 + 0.36 * pressure))
  }

  private func play(_ cue: TurboCue, rate: Float = 1) {
    if soundEnabled && scenePhase == .active { sounds.play(cue, rate: rate) }
  }
}
