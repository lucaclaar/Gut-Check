import AVFoundation

@MainActor
final class TurboSounds {
  private var players: [TurboCue: [AVAudioPlayer]] = [:]
  private var configured = false

  func load() {
    guard players.isEmpty else { return }
    for cue in TurboCue.allCases {
      let name = "turbo-\(cue.rawValue)"
      guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "TurboAudio")
        ?? Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
      let count = cue == .tap ? 3 : 1
      players[cue] = (0..<count).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
    }
  }

  func play(_ cue: TurboCue, rate: Float = 1) {
    load()
    guard let voices = players[cue], let player = voices.first(where: { !$0.isPlaying }) ?? voices.first
    else { return }
    if !configured {
      do {
        // Mix with other audio and honor the system's Silent Mode.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        configured = true
      } catch { return }
    }
    player.currentTime = 0
    player.enableRate = true
    player.rate = rate
    player.play()
  }

  func stop() {
    for player in players.values.joined() { player.stop() }
    configured = false
  }
}
