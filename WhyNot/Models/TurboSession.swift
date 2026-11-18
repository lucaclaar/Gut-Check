import Foundation
import Observation

@MainActor @Observable
final class TurboSession {
  var options = [TurboOption(text: "Tacos"), TurboOption(text: "Sushi"),
    TurboOption(text: "Pizza"), TurboOption()]
  private(set) var phase: TurboPhase = .setup
  private(set) var bubbles: [TurboBubble] = []
  private(set) var elapsed = 0.0
  private(set) var countdownRemaining = 3.0
  private(set) var chosenID: UUID?
  private(set) var reserves: [Double] = []
  private(set) var duration = 16.0
  var feeling = 0.75
  var saveError: String?
  private(set) var savedDecisions: [SavedTurboDecision] = []
  private(set) var lastSaved: SavedTurboDecision?
  @ObservationIgnored private var lastTick: TimeInterval?
  @ObservationIgnored private var roundID = UUID()
  @ObservationIgnored private let storageURL: URL

  init(storageURL: URL = URL.documentsDirectory.appending(path: "turbo-decisions.json")) {
    self.storageURL = storageURL
    if let data = try? Data(contentsOf: storageURL),
      let records = try? JSONDecoder().decode([SavedTurboDecision].self, from: data) {
      savedDecisions = records
    }
  }

  var filledOptions: [TurboOption] {
    options.compactMap { option in
      let text = option.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? nil : TurboOption(id: option.id, text: text)
    }
  }
  var validationMessage: String? {
    let filled = filledOptions
    guard (3...6).contains(filled.count) else { return "Add 3 to 6 options to start." }
    let unique = Set(filled.map { $0.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
    guard unique.count == filled.count else { return "Give each option a different name." }
    guard filled.allSatisfy({ $0.text.count <= 60 }) else { return "Keep each option under 60 characters." }
    return nil
  }
  var canStart: Bool { validationMessage == nil }
  var plannedSeconds: Int { 4 + 4 * filledOptions.count }
  var screeningText: String { options.map(\.text).joined(separator: ". ") }
  var safetyConcern: SafetyConcern? { SafetyScreening.concern(in: screeningText) }
  var remaining: Double { max(0, duration - elapsed) }
  var secondsRemaining: Int { Int(ceil(remaining)) }
  var countdownNumber: Int { max(1, Int(ceil(countdownRemaining))) }
  var activeBubbles: [TurboBubble] { bubbles.filter { !$0.isPopped } }
  var chosen: TurboBubble? { bubbles.first { $0.id == chosenID } }
  var minimumReserve: Double { activeBubbles.map { reserves[$0.slot] }.min() ?? 1 }
  var feelingTitle: String {
    if feeling < 0.33 { "Not great" } else if feeling < 0.66 { "Not sure yet" } else { "Pretty relieved" }
  }
  var feelingMascot: String {
    if feeling < 0.33 { "MascotWorstCase4" } else if feeling < 0.66 { "MascotStillDoubtful1" } else { "MascotBestCase1" }
  }

  func prepare() {
    phase = .setup
    lastTick = nil
    chosenID = nil
    lastSaved = nil
    saveError = nil
  }

  @discardableResult
  func addOption() -> UUID? {
    if let empty = options.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
      return empty.id
    }
    guard options.count < 6 else { return nil }
    let option = TurboOption()
    options.append(option)
    return option.id
  }

  func removeOption(_ id: UUID) {
    guard options.count > 3 else { return }
    options.removeAll { $0.id == id }
  }

  @discardableResult
  func start() -> Bool {
    guard canStart, safetyConcern == nil else { return false }
    bubbles = filledOptions.enumerated().map { slot, option in
      TurboBubble(id: option.id, text: option.text, slot: slot)
    }
    roundID = UUID()
    elapsed = 0
    duration = Double(plannedSeconds)
    reserves = Array(repeating: 1, count: bubbles.count)
    chosenID = nil
    lastSaved = nil
    feeling = 0.75
    saveError = nil
    lastTick = nil
    countdownRemaining = 3
    phase = .countdown
    return true
  }

  /// Monotonic time avoids wall-clock changes and timer drift. The UI owns the
  /// cancellable ticking task; paused/background time never contributes to elapsed.
  func tick(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing || phase == .countdown else { lastTick = nil; return }
    guard let previous = lastTick else { lastTick = now; return }
    guard now >= previous else { return }
    var delta = now - previous
    lastTick = now
    if phase == .countdown {
      let countdownDelta = min(countdownRemaining, delta)
      countdownRemaining -= countdownDelta
      guard countdownRemaining == 0 else { return }
      phase = .playing
      delta -= countdownDelta
    }
    let oldProgress = elapsed / duration
    elapsed = min(duration, elapsed + delta)
    let progress = elapsed / duration
    // Integral of the accelerating drain across this tick, independent of frame rate.
    let drain = (progress - oldProgress) * (1.6 + 0.6 * (progress + oldProgress))
    var nextReserves = reserves
    for bubble in activeBubbles {
      nextReserves[bubble.slot] = max(0, nextReserves[bubble.slot] - drain)
    }
    let bursting = activeBubbles.filter { nextReserves[$0.slot] <= 0 }
    let lastRescuedBurst = preferred(bursting)
    reserves = nextReserves
    for bubble in bursting { bubbles[bubble.slot].isPopped = true }
    if activeBubbles.isEmpty {
      finish(with: lastRescuedBurst)
    } else if elapsed >= duration || activeBubbles.count == 1 {
      finish(with: preferred(activeBubbles) ?? lastRescuedBurst)
    }
  }

  func pause(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing || phase == .countdown else { return }
    tick(at: now)
    guard phase == .playing || phase == .countdown else { return }
    phase = .paused
    lastTick = nil
  }

  func resume(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .paused else { return }
    countdownRemaining = 3
    lastTick = now
    phase = .countdown
  }

  func rescue(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing,
      let index = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return }
    tick(at: now)
    guard phase == .playing, !bubbles[index].isPopped,
      elapsed - bubbles[index].lastRescuedAt >= 0.05 else { return }
    bubbles[index].rescues += 1
    bubbles[index].lastRescuedAt = elapsed
    reserves[index] = min(1, reserves[index] + 0.1)
  }

  func discard(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing else { return }
    tick(at: now)
    guard phase == .playing,
      let index = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return }
    bubbles[index].isPopped = true
    if activeBubbles.count <= 1 { finish(with: preferred(activeBubbles)) }
  }

  func choose(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing else { return }
    tick(at: now)
    guard phase == .playing, bubbles.contains(where: { $0.id == id && !$0.isPopped }) else { return }
    finish(with: bubbles.first { $0.id == id })
  }

  func continueToFeeling() {
    guard phase == .picked, chosen != nil else { return }
    phase = .feeling
  }

  func returnToResult() {
    if phase == .feeling { phase = .picked }
  }

  func saveDecision() {
    guard phase == .feeling, let chosen, lastSaved == nil else { return }
    let record = SavedTurboDecision(id: roundID, createdAt: .now, choice: chosen.text,
      options: bubbles, decidedIn: elapsed, feeling: min(1, max(0, feeling)))
    do {
      let next = savedDecisions + [record]
      try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(next).write(to: storageURL, options: [.atomic, .completeFileProtection])
      savedDecisions = next
      lastSaved = record
      saveError = nil
      phase = .saved
    } catch { saveError = error.localizedDescription }
  }

  private func preferred(_ candidates: [TurboBubble]) -> TurboBubble? {
    candidates.filter { $0.rescues > 0 }.max {
      if reserves[$0.slot] != reserves[$1.slot] { return reserves[$0.slot] < reserves[$1.slot] }
      if $0.rescues != $1.rescues { return $0.rescues < $1.rescues }
      return $0.lastRescuedAt < $1.lastRescuedAt
    }
  }

  private func finish(with bubble: TurboBubble?) {
    chosenID = bubble?.id
    phase = bubble == nil ? .timedOut : .picked
    lastTick = nil
  }
}
