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
  private var audibleCountdown: Int? {
    scenePhase == .active && session.phase == .countdown ? session.countdownNumber : nil
  }
  private var roundOver: Bool {
    session.phase == .picked || session.phase == .timedOut || session.phase == .tie
  }

  var body: some View {
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
    .task { if soundEnabled { sounds.load() } }
    .task(id: scenePhase == .active ? session.phase : nil) {
      guard scenePhase == .active else { return }
      if roundOver {
        do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
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
    .onChange(of: scenePhase, initial: true) { _, phase in
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
    .onChange(of: session.phase) { _, phase in
      if phase == .paused { sounds.stop() }
    }
    .onChange(of: audibleCountdown, initial: true) { _, number in
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

  private var instruction: String {
    if session.activeBubbles.contains(where: session.isAboutToPop) { return "Tap to save it before it pops." }
    return "Tap to save · Flick to let go · Hold to pick"
  }

  private func pulseIfNeeded() {
    guard session.phase == .playing, session.elapsed >= nextPulse,
      session.minimumReserve < 0.40 || session.remaining <= 2 else { return }
    let reserve = session.minimumReserve
    nextPulse = session.elapsed + 0.36 + 0.64 * reserve
    play(.pulse, rate: Float(1.0 + 0.26 * (1 - reserve)))
  }

  private func play(_ cue: TurboCue, rate: Float = 1) {
    if soundEnabled && scenePhase == .active { sounds.play(cue, rate: rate) }
  }
}
