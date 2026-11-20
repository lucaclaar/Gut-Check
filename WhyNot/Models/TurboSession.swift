import Foundation
import Observation

@MainActor @Observable
final class TurboSession {
  var options = [TurboOption(), TurboOption(), TurboOption()]
  private(set) var phase: TurboPhase = .setup
  private(set) var bubbles: [TurboBubble] = []
  private(set) var elapsed = 0.0
  private(set) var countdownRemaining = 3.0
  private(set) var chosenID: UUID?
  private(set) var reserves: [Double] = []
  private(set) var duration = 9.0
  var feeling = 0.75
  private(set) var reviewingPick = false
  private(set) var hasReviewedPick = false
  private(set) var alternativeID: UUID?
  private var discardedIDs: Set<UUID> = []
  @ObservationIgnored private var resumedDecisionID: UUID?
  @ObservationIgnored private var lifetimes: [Double] = []
  @ObservationIgnored private var deadlines: [Double] = []
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
  var duplicateOptionIDs: Set<UUID> {
    let groups = Dictionary(grouping: filledOptions) {
      $0.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
    return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
  }

  var validationMessage: String? {
    if !duplicateOptionIDs.isEmpty { return "Give each option a different name." }
    if filledOptions.contains(where: { $0.text.count > 60 }) {
      return "Keep each option to 60 characters or fewer."
    }
    if filledOptions.count < 3 { return "Add at least 3 options to start." }
    if filledOptions.count > 6 { return "Use at most 6 options." }
    return nil
  }
  var canStart: Bool { validationMessage == nil }
  var plannedSeconds: Int { 3 + 2 * filledOptions.count }
  var screeningText: String { options.map(\.text).joined(separator: ". ") }
  var safetyConcern: SafetyConcern? { SafetyScreening.concern(in: screeningText) }
  var remaining: Double { max(0, duration - elapsed) }
  var secondsRemaining: Int { Int(ceil(remaining)) }
  var countdownNumber: Int { max(1, Int(ceil(countdownRemaining))) }
  var activeBubbles: [TurboBubble] { bubbles.filter { !$0.isPopped } }
  var chosen: TurboBubble? { bubbles.first { $0.id == chosenID } }
  var finalChoice: TurboBubble? { bubbles.first { $0.id == alternativeID } ?? chosen }
  var alternatives: [TurboBubble] {
    bubbles.filter { $0.id != chosenID && !discardedIDs.contains($0.id) }
      + bubbles.filter { $0.id != chosenID && discardedIDs.contains($0.id) }
  }
  var suggestedAlternative: TurboBubble? {
    alternatives.filter { $0.rescues > 0 && !discardedIDs.contains($0.id) }.max {
      if $0.rescues != $1.rescues { return $0.rescues < $1.rescues }
      return $0.lastRescuedAt < $1.lastRescuedAt
    }
  }
  var minimumReserve: Double { activeBubbles.map { reserves[$0.slot] }.min() ?? 1 }
  var feelingTitle: String { ReflectionSession.feelingTitle(for: feeling) }
  var feelingMascot: String { ReflectionSession.feelingMascot(for: feeling) }

  func prepare() {
    phase = .setup
    lastTick = nil
    chosenID = nil
    lastSaved = nil
    saveError = nil
  }

  func prepareNew() {
    resumedDecisionID = nil
    options = [TurboOption(), TurboOption(), TurboOption()]
    prepare()
  }

  @discardableResult
  func resumeDecision(_ id: UUID) -> Bool {
    guard let record = savedDecisions.first(where: { $0.id == id }) else { return false }
    let restored = record.options.sorted { $0.slot < $1.slot }.prefix(6)
    options = restored.map { TurboOption(id: $0.id, text: $0.text) }
    if options.isEmpty { options = [TurboOption(text: record.choice)] }
    while options.count < 3 { options.append(TurboOption()) }
    resumedDecisionID = id
    prepare()
    return true
  }

  func deleteDecision(_ id: UUID) throws {
    try persist(savedDecisions.filter { $0.id != id })
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

  func optionText(for id: UUID) -> String {
    options.first { $0.id == id }?.text ?? ""
  }

  func setOptionText(_ text: String, for id: UUID) {
    guard let index = options.firstIndex(where: { $0.id == id }),
      options[index].text != text else { return }
    options[index].text = text
  }

  func removeOption(_ id: UUID) {
    guard let index = options.firstIndex(where: { $0.id == id }) else { return }
    if options.count > 3 { options.remove(at: index) } else { options[index].text = "" }
  }

  @discardableResult
  func start() -> Bool {
    var generator = SystemRandomNumberGenerator()
    return start(using: &generator)
  }

  @discardableResult
  func start(using generator: inout some RandomNumberGenerator) -> Bool {
    guard canStart, safetyConcern == nil else { return false }
    bubbles = filledOptions.enumerated().map { slot, option in
      TurboBubble(id: option.id, text: option.text, slot: slot)
    }
    roundID = resumedDecisionID ?? UUID()
    elapsed = 0
    duration = Double(plannedSeconds)
    // Keep a short window for reading the options, then stagger bursts.
    let firstLifetime = duration * 0.53
    let interval = duration * 0.42 / Double(bubbles.count - 1)
    lifetimes = bubbles.indices.map { firstLifetime + Double($0) * interval }
      .shuffled(using: &generator)
    deadlines = lifetimes
    discardedIDs = []
    alternativeID = nil
    reviewingPick = false
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
    elapsed = min(duration, elapsed + delta)
    let active = activeBubbles
    var nextReserves = reserves
    for bubble in active {
      let slot = bubble.slot
      nextReserves[slot] = min(1, max(0, (deadlines[slot] - elapsed) / lifetimes[slot]))
    }
    reserves = nextReserves

    // Process missed expirations in time order, including after a slow frame.
    let bursting = active.filter { nextReserves[$0.slot] == 0 }
      .sorted { deadlines[$0.slot] < deadlines[$1.slot] }
    for bubble in bursting {
      bubbles[bubble.slot].isPopped = true
      let survivors = activeBubbles
      if survivors.count <= 1 {
        elapsed = deadlines[bubble.slot]
        finish(with: preferred(survivors) ?? preferred([bubble]))
        return
      }
    }
    if elapsed >= duration { finish(with: preferred(activeBubbles)) }
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
    deadlines[index] = min(elapsed + lifetimes[index], deadlines[index] + 0.72)
    reserves[index] = (deadlines[index] - elapsed) / lifetimes[index]
  }

  func discard(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing else { return }
    tick(at: now)
    guard phase == .playing,
      let index = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return }
    bubbles[index].isPopped = true
    discardedIDs.insert(id)
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
    feeling = 0.75
    reviewingPick = false
    hasReviewedPick = false
    alternativeID = nil
    phase = .feeling
  }

  func returnToResult() {
    if phase == .feeling { phase = .picked }
  }

  func reviewPick() {
    guard phase == .feeling, feeling < 0.33 else { return }
    reviewingPick = true
  }

  func chooseAlternative(_ id: UUID) {
    guard reviewingPick, alternatives.contains(where: { $0.id == id }) else { return }
    alternatePick(id, feeling: 0.5)
  }

  func keepOriginalPick() {
    guard reviewingPick else { return }
    alternatePick(nil, feeling: feeling)
  }

  private func alternatePick(_ id: UUID?, feeling: Double) {
    alternativeID = id
    self.feeling = feeling
    reviewingPick = false
    hasReviewedPick = true
  }

  func saveDecision() {
    guard phase == .feeling, let finalChoice, lastSaved == nil else { return }
    let record = SavedTurboDecision(id: roundID, createdAt: .now, choice: finalChoice.text,
      options: bubbles, decidedIn: elapsed, feeling: min(1, max(0, feeling)))
    do {
      try persist(savedDecisions.filter { $0.id != record.id } + [record])
      resumedDecisionID = nil
      lastSaved = record
      saveError = nil
      phase = .saved
    } catch { saveError = error.localizedDescription }
  }

  private func persist(_ records: [SavedTurboDecision]) throws {
    try FileManager.default.createDirectory(
      at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(records).write(to: storageURL,
      options: [.atomic, .completeFileProtection])
    savedDecisions = records
  }

  private func preferred(_ candidates: [TurboBubble]) -> TurboBubble? {
    candidates.filter { $0.rescues > 0 }.max {
      if $0.rescues != $1.rescues { return $0.rescues < $1.rescues }
      if reserves[$0.slot] != reserves[$1.slot] { return reserves[$0.slot] < reserves[$1.slot] }
      return $0.lastRescuedAt < $1.lastRescuedAt
    }
  }

  private func finish(with bubble: TurboBubble?) {
    chosenID = bubble?.id
    phase = bubble == nil ? .timedOut : .picked
    lastTick = nil
  }
}
