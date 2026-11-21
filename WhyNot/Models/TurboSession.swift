import Foundation
import Observation

@MainActor @Observable
final class TurboSession {
  var options = [TurboOption(), TurboOption(), TurboOption()]
  let rules: TurboRules
  private(set) var phase: TurboPhase = .setup
  private(set) var bubbles: [TurboBubble] = []
  private(set) var elapsed = 0.0
  private(set) var countdownRemaining = 3.0
  private(set) var chosenID: UUID?
  private(set) var outcome: TurboOutcome?
  /// Options that ended level on taps when time ran out.
  private(set) var tiedIDs: [UUID] = []
  /// Time left on each option's hidden timer, by slot.
  private(set) var timeLeft: [Double] = []
  /// The hidden timer each option started with, by slot.
  private(set) var timers: [Double] = []
  var feeling = 0.5
  private(set) var reviewingPick = false
  private(set) var hasReviewedPick = false
  private(set) var alternativeID: UUID?
  /// After switching to the runner-up, the feeling is asked again for that option
  /// before saving, so the saved feeling is about the final choice.
  private(set) var needsAlternativeFeeling = false
  var saveError: String?
  private(set) var savedDecisions: [SavedTurboDecision] = []
  private(set) var lastSaved: SavedTurboDecision?
  @ObservationIgnored private var resumedDecisionID: UUID?
  @ObservationIgnored private var lastTick: TimeInterval?
  @ObservationIgnored private var roundID = UUID()
  @ObservationIgnored private let storageURL: URL

  init(storageURL: URL = URL.documentsDirectory.appending(path: "turbo-decisions.json"),
    rules: TurboRules = TurboRules()) {
    self.storageURL = storageURL
    self.rules = rules
    if let data = try? Data(contentsOf: storageURL),
      let records = try? JSONDecoder().decode([SavedTurboDecision].self, from: data) {
      savedDecisions = records
    }
  }

  // MARK: Options

  var filledOptions: [TurboOption] {
    options.compactMap { option in
      let text = option.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? nil : TurboOption(id: option.id, text: text)
    }
  }

  /// Each option that repeats an earlier one, mapped to the earlier option's text.
  /// Capitals, accents and extra spaces don't make two options different.
  var repeatedOptions: [UUID: String] {
    var firstByKey: [String: String] = [:]
    var repeats: [UUID: String] = [:]
    for option in filledOptions {
      let key = option.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
      if let first = firstByKey[key] { repeats[option.id] = first } else { firstByKey[key] = option.text }
    }
    return repeats
  }

  var validationMessage: String? {
    if !repeatedOptions.isEmpty { return "Change the repeated option to start." }
    if filledOptions.contains(where: { $0.text.count > 60 }) {
      return "Keep each option to 60 characters or fewer."
    }
    if filledOptions.count < 3 { return "Add at least 3 options to start." }
    if filledOptions.count > 6 { return "Use at most 6 options." }
    return nil
  }
  var canStart: Bool { validationMessage == nil }
  var hasTypedOptions: Bool { !filledOptions.isEmpty }
  var screeningText: String { options.map(\.text).joined(separator: ". ") }
  var safetyConcern: SafetyConcern? { SafetyScreening.concern(in: screeningText) }

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

  // MARK: Round state

  var duration: Double { rules.round }
  var remaining: Double { max(0, duration - elapsed) }
  var secondsRemaining: Int { Int(ceil(remaining)) }
  var countdownNumber: Int { max(1, Int(ceil(countdownRemaining))) }
  var activeBubbles: [TurboBubble] { bubbles.filter { !$0.isPopped } }
  var chosen: TurboBubble? { bubbles.first { $0.id == chosenID } }
  var finalChoice: TurboBubble? { bubbles.first { $0.id == alternativeID } ?? chosen }
  var tiedBubbles: [TurboBubble] { bubbles.filter { tiedIDs.contains($0.id) } }

  /// Liquid level for each option: the time it has left out of a full bubble.
  var reserves: [Double] { timeLeft.map { min(1, max(0, $0 / rules.maximumTimer)) } }
  var minimumReserve: Double { activeBubbles.map { reserves[$0.slot] }.min() ?? 1 }
  func isAboutToPop(_ bubble: TurboBubble) -> Bool {
    !bubble.isPopped && timeLeft.indices.contains(bubble.slot) && timeLeft[bubble.slot] <= rules.lastSecondWindow
  }

  // MARK: Start, play, pause

  func prepare() {
    phase = .setup
    lastTick = nil
    chosenID = nil
    outcome = nil
    lastSaved = nil
    saveError = nil
  }

  func prepareNew() {
    resumedDecisionID = nil
    options = [TurboOption(), TurboOption(), TurboOption()]
    prepare()
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
    // Spread the hidden timers so options expire at clearly different moments,
    // then shuffle so the order they were typed in never predicts the first to go.
    let count = bubbles.count
    let span = rules.longestTimer - rules.shortestTimer
    let jitter = rules.round * 0.04
    timers = (0..<count).map { index in
      let spread = rules.shortestTimer + span * Double(index) / Double(count - 1)
      let wobble = Double.random(in: -jitter...jitter, using: &generator)
      let value = min(rules.longestTimer, max(rules.shortestTimer * 0.8, spread + wobble))
      return (value * 10).rounded() / 10
    }.shuffled(using: &generator)
    timeLeft = timers
    elapsed = 0
    chosenID = nil
    outcome = nil
    tiedIDs = []
    alternativeID = nil
    needsAlternativeFeeling = false
    reviewingPick = false
    hasReviewedPick = false
    lastSaved = nil
    feeling = 0.5
    saveError = nil
    lastTick = nil
    countdownRemaining = 3
    phase = .countdown
    return true
  }

  /// Monotonic time avoids wall-clock changes and timer drift. The UI owns the
  /// cancellable ticking task; paused and background time never count.
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
    advance(by: min(delta, duration - elapsed))
    if phase == .playing && elapsed >= duration { finishAtTimeUp() }
  }

  /// Moves the round forward, popping options in the order their timers run out,
  /// even when a slow frame skips past several of them at once.
  private func advance(by delta: Double) {
    guard delta > 0 else { return }
    let start = elapsed
    let end = start + delta
    // Work out every pop time before the clock moves; moving drains timeLeft.
    let popping = activeBubbles.map { (slot: $0.slot, at: start + timeLeft[$0.slot]) }
      .filter { $0.at <= end }.sorted { $0.at < $1.at }
    for (slot, poppedAt) in popping {
      let bubble = bubbles[slot]
      move(to: poppedAt)
      bubbles[bubble.slot].isPopped = true
      bubbles[bubble.slot].endedAt = poppedAt
      if endIfDecided() { return }
    }
    move(to: end)
  }

  private func move(to time: Double) {
    let step = time - elapsed
    guard step > 0 else { return }
    for bubble in activeBubbles { timeLeft[bubble.slot] = max(0, timeLeft[bubble.slot] - step) }
    elapsed = time
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

  // MARK: Player actions

  enum SaveResult: Equatable { case saved(lastSecond: Bool), full, ignored }

  /// Tap to save: every tap adds `tapBonus` to the option, up to a full bubble.
  /// Taps are unlimited, but they add time to the option, never to the round.
  @discardableResult
  func save(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> SaveResult {
    guard phase == .playing else { return .ignored }
    tick(at: now)
    guard phase == .playing,
      let slot = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return .ignored }
    bubbles[slot].taps += 1
    bubbles[slot].lastRescuedAt = elapsed
    guard timeLeft[slot] < rules.maximumTimer else { return .full }
    let lastSecond = timeLeft[slot] <= rules.lastSecondWindow
    timeLeft[slot] = min(rules.maximumTimer, timeLeft[slot] + rules.tapBonus)
    bubbles[slot].rescues += 1
    if lastSecond { bubbles[slot].lastSecondSaves += 1 }
    return .saved(lastSecond: lastSecond)
  }

  /// Flick to let go. A let-go option can never come back as the result.
  func discard(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing else { return }
    tick(at: now)
    guard phase == .playing,
      let slot = bubbles.firstIndex(where: { $0.id == id && !$0.isPopped }) else { return }
    bubbles[slot].isPopped = true
    bubbles[slot].isDiscarded = true
    bubbles[slot].endedAt = elapsed
    endIfDecided()
  }

  /// Hold to pick right away.
  func choose(_ id: UUID, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard phase == .playing else { return }
    tick(at: now)
    guard phase == .playing, let bubble = activeBubbles.first(where: { $0.id == id }) else { return }
    finish(with: bubble, outcome: .held)
  }

  /// After a tie, the person picks between the tied options with no timer.
  func breakTie(_ id: UUID) {
    guard phase == .tie, let bubble = tiedBubbles.first(where: { $0.id == id }) else { return }
    finish(with: bubble, outcome: .tieBreak)
  }

  /// Tapping or letting go is how the gut speaks. A round with neither has no pick.
  private var gutSpoke: Bool { bubbles.contains { $0.taps > 0 || $0.isDiscarded } }

  @discardableResult
  private func endIfDecided() -> Bool {
    let survivors = activeBubbles
    if survivors.count == 1 {
      finish(with: gutSpoke ? survivors[0] : nil, outcome: gutSpoke ? .lastStanding : nil)
      return true
    }
    if survivors.isEmpty { finish(with: nil, outcome: nil); return true }
    return false
  }

  private func finishAtTimeUp() {
    let survivors = activeBubbles
    // The option tapped most wins; equal taps make a tie the person breaks.
    guard let most = survivors.map(\.taps).max(), gutSpoke else { finish(with: nil, outcome: nil); return }
    let leaders = survivors.filter { $0.taps == most }
    if leaders.count == 1 {
      finish(with: leaders[0], outcome: .mostSaves)
    } else {
      tiedIDs = leaders.map(\.id)
      phase = .tie
      lastTick = nil
    }
  }

  private func finish(with bubble: TurboBubble?, outcome: TurboOutcome?) {
    chosenID = bubble?.id
    self.outcome = outcome
    phase = bubble == nil ? .timedOut : .picked
    lastTick = nil
  }

  // MARK: Feeling and runner-up

  var feelingTitle: String { ReflectionSession.feelingTitle(for: feeling) }
  var feelingMascot: String { ReflectionSession.feelingMascot(for: feeling) }
  var feelsNotGreat: Bool { feeling < 0.33 }

  /// The option the person reached for most besides the pick: most taps, then
  /// the one that lasted longest. Options they let go never come back.
  var runnerUp: TurboBubble? {
    func lasted(_ bubble: TurboBubble) -> Double { bubble.endedAt ?? elapsed }
    return bubbles.filter { $0.id != chosenID && !$0.isDiscarded }.max {
      if $0.taps != $1.taps { return $0.taps < $1.taps }
      return lasted($0) < lasted($1)
    }
  }

  func continueToFeeling() {
    guard phase == .picked, chosen != nil else { return }
    feeling = 0.5
    reviewingPick = false
    hasReviewedPick = false
    alternativeID = nil
    needsAlternativeFeeling = false
    phase = .feeling
  }

  func returnToResult() {
    if phase == .feeling { phase = .picked }
  }

  /// "Save my decision": a pick that feels not great first gets the runner-up suggestion.
  func confirmFeeling() {
    guard phase == .feeling else { return }
    if needsAlternativeFeeling {
      needsAlternativeFeeling = false
      saveDecision()
    } else if feelsNotGreat && !hasReviewedPick && runnerUp != nil {
      reviewingPick = true
    } else {
      saveDecision()
    }
  }

  func backToFeeling() {
    if reviewingPick { reviewingPick = false }
  }

  /// Switches to the runner-up and asks how that option feels before saving.
  func chooseRunnerUp() {
    guard reviewingPick, let runnerUp else { return }
    alternativeID = runnerUp.id
    reviewingPick = false
    hasReviewedPick = true
    needsAlternativeFeeling = true
    feeling = 0.5
  }

  func rateAlternative(_ rating: Double) {
    guard phase == .feeling, needsAlternativeFeeling else { return }
    feeling = min(1, max(0, rating))
    needsAlternativeFeeling = false
  }

  func keepOriginalPick() {
    guard reviewingPick else { return }
    reviewingPick = false
    hasReviewedPick = true
    saveDecision()
  }

  var switchedFromGut: Bool { alternativeID != nil }

  // MARK: Saving

  func saveDecision() {
    guard phase == .feeling, !reviewingPick, !needsAlternativeFeeling,
      let finalChoice, lastSaved == nil else { return }
    let record = SavedTurboDecision(id: roundID, createdAt: .now, choice: finalChoice.text,
      options: bubbles, decidedIn: elapsed, feeling: min(1, max(0, feeling)),
      gutPick: switchedFromGut ? chosen?.text : nil)
    do {
      try persist(savedDecisions.filter { $0.id != record.id } + [record])
      resumedDecisionID = nil
      lastSaved = record
      saveError = nil
      phase = .saved
    } catch { saveError = error.localizedDescription }
  }

  /// Keeps the options as an unfinished decision. Resuming starts a fresh round
  /// with new timers: half a round with known timers is no longer a gut test.
  @discardableResult
  func saveForLater() -> Bool {
    let typed = filledOptions
    guard !typed.isEmpty else { return false }
    let id = resumedDecisionID ?? UUID()
    let options = typed.enumerated().map { TurboBubble(id: $1.id, text: $1.text, slot: $0) }
    let record = SavedTurboDecision(id: id, createdAt: .now, choice: "", options: options,
      decidedIn: 0, feeling: 0, isUnfinished: true)
    do {
      try persist(savedDecisions.filter { $0.id != id } + [record])
      saveError = nil
      bubbles = []
      prepareNew()
      return true
    } catch {
      saveError = error.localizedDescription
      return false
    }
  }

  /// Drops the current decision, including its unfinished copy if it was resumed.
  func discardCurrent() throws {
    if let id = resumedDecisionID { try deleteDecision(id) }
    bubbles = []
    prepareNew()
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

  private func persist(_ records: [SavedTurboDecision]) throws {
    try FileManager.default.createDirectory(
      at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(records).write(to: storageURL,
      options: [.atomic, .completeFileProtection])
    savedDecisions = records
  }
}
