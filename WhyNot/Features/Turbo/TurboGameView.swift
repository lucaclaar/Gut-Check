import SwiftUI

struct TurboGameView: View {
  let session: TurboSession
  let finish: () -> Void
  let leave: () -> Void
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

  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        TurboTimerView(session: session).padding(.top, 16)
        Spacer(minLength: 18)
        TurboBubbleArena(session: session)
          .frame(height: max(180, min(440, proxy.size.height - 240)))
        Spacer(minLength: 18)
        Text(instruction)
          .font(.footnote).foregroundStyle(GutTheme.muted).multilineTextAlignment(.center)
          .padding(.horizontal, 16).padding(.bottom, 48)
      }
      .frame(maxWidth: 500).frame(maxWidth: .infinity)
      .allowsHitTesting(!covered)
      .accessibilityHidden(covered)
    }
    .padding(.horizontal, 24)
    .background(GutBackground(origin: CGPoint(x: 172, y: 580)))
    .overlay {
      if covered {
        TurboPauseOverlay(session: session, isAppSwitcherCover: scenePhase != .active, leave: leave)
      }
    }
    .navigationTitle("Turbo").navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarVisibility(scenePhase == .active ? .automatic : .hidden, for: .navigationBar)
    .toolbar {
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
    .task { sounds.load() }
    .task(id: scenePhase == .active ? session.phase : nil) {
      guard scenePhase == .active else { return }
      if session.phase == .picked || session.phase == .timedOut {
        do { try await Task.sleep(for: .milliseconds(320)) } catch { return }
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
      if current < previous { play(.burst) }
    }
    .onDisappear { session.pause(); sounds.stop() }
  }

  private var instruction: String {
    if session.minimumReserve < 0.32 { return "Tap to refill before the bubbles burst." }
    return "Tap to refill. Hold to choose. Flick to discard."
  }

  private func pulseIfNeeded() {
    guard session.phase == .playing, session.elapsed >= nextPulse,
      session.minimumReserve < 0.46 || session.remaining <= 5 else { return }
    let reserve = session.minimumReserve
    nextPulse = session.elapsed + 0.19 + 0.7 * reserve
    play(.pulse, rate: Float(1.1 + 0.65 * (1 - reserve)))
  }

  private func play(_ cue: TurboCue, rate: Float = 1) {
    if soundEnabled && scenePhase == .active { sounds.play(cue, rate: rate) }
  }
}
