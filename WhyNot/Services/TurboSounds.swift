import AVFoundation

/// Plays Turbo's sound cues for the views. All audio work happens on the
/// `TurboAudio` actor, off the main thread, so configuring the audio session or
/// preparing players can never stall the UI while someone is tapping.
@MainActor
final class TurboSounds {
  private let audio = TurboAudio()

  func load() { Task { await audio.load() } }
  func play(_ cue: TurboCue, rate: Float = 1) { Task { await audio.play(cue, rate: rate) } }
  func stop() { Task { await audio.stop() } }
}

/// Owns the audio session setup and the players. Being an actor keeps every
/// AVAudioSession and AVAudioPlayer call off the main thread and in order.
actor TurboAudio {
  private var players: [TurboCue: [AVAudioPlayer]] = [:]
  private var configured = false

  func load() {
    if !configured {
      do {
        // Mix with other audio and honor the system's Silent Mode. The category
        // stays set for the life of the app, so this runs once.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        configured = true
      } catch { return }
    }
    guard players.isEmpty else { return }
    for cue in TurboCue.allCases {
      let name = "turbo-\(cue.rawValue)"
      guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "TurboAudio")
        ?? Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
      let count = cue == .tap ? 3 : 1
      players[cue] = (0..<count).compactMap { _ in
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.enableRate = true
        player.volume = cue == .pulse ? 0.29 : cue == .burst ? 0.55 : 0.8
        player.prepareToPlay()
        return player
      }
    }
  }

  func play(_ cue: TurboCue, rate: Float) {
    load()
    guard configured, let voices = players[cue], let player = voices.first(where: { !$0.isPlaying })
    else { return }
    player.currentTime = 0
    player.rate = rate
    player.play()
  }

  func stop() {
    for player in players.values.joined() { player.stop() }
  }
}
