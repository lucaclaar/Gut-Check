import Foundation
import Observation

@MainActor @Observable
final class ReflectionSession {
  var path: [ReflectionRoute] = [] {
    didSet {
      if path.last != .cards { stopCardPreparation() }
    }
  }
  var question = ""
  var lens: ReflectionLens = .best
  var cards = ReflectionQuestion.deck(for: .best)
  private(set) var isPreparingCards = false
  private(set) var usesPersonalizedCards = false
  var showCardGenerationIssue = false
  var index = 0
  var answers: [ReflectionAnswer] = []
  var decision = ""
  var feeling = 0.75
  var walks = 0
  var walkedSteps = 0
  private var walk: WalkExchange.Request?
  private(set) var phoneWalkSteps = 0
  private(set) var watchWalkSteps: Int?
  private(set) var lastFinishedWalk: WalkExchange.Completion?
  var showSaveError = false
  var saveError = ""
  var lastSaved: SavedDecision?
  var savedDecisions: [SavedDecision] = []
  var readyAfter = Date.distantPast
  var safetyConcern: SafetyConcern? {
    didSet {
      if safetyConcern != nil { cancelCardPreparation() }
    }
  }
  private var resumedDecisionID: UUID?
  @ObservationIgnored private var lastShownConcern: SafetyConcern?
  @ObservationIgnored private let storageURL: URL
  @ObservationIgnored private let walkDraftURL: URL
  @ObservationIgnored private var cardPreparation: ReflectionCardPreparation?

  init(storageURL: URL = URL.documentsDirectory.appending(path: "decisions.json")) {
    self.storageURL = storageURL
    walkDraftURL = storageURL.deletingPathExtension().appendingPathExtension("walk-draft.json")
    if let data = try? Data(contentsOf: storageURL),
      let decisions = try? JSONDecoder().decode([SavedDecision].self, from: data)
    {
      savedDecisions = decisions
    }
    if let data = try? Data(contentsOf: walkDraftURL),
      let draft = try? JSONDecoder().decode(ReflectionWalkDraft.self, from: data)
    {
      question = draft.question
      lens = draft.lens
      answers = draft.answers
      walks = draft.walks
      orderCards()
      if let deck = draft.cards,
        ReflectionQuestion.personalized(deck.map(\.text), for: draft.lens) == deck
      {
        cards = deck
        usesPersonalizedCards = true
      }
      index = min(max(0, draft.cardIndex ?? (cards.count - 1)), cards.count - 1)
      path = [.setup, .cards, .pause, .walk]
      if let steps = draft.finishedSteps {
        walkedSteps = steps
        lastFinishedWalk = WalkExchange.Completion(id: draft.request.id, steps: steps)
        path.append(.returnFromWalk)
      } else {
        walk = draft.request
      }
    }
  }
  var currentCard: ReflectionQuestion { cards[min(index, cards.count - 1)] }
  var yesCount: Int { answers.count(where: \.yes) }
  var noCount: Int { answers.count - yesCount }
  var canStart: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var canSave: Bool { !decision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var currentWalk: WalkExchange.Request? { path.last == .walk ? walk : nil }
  var currentWalkSteps: Int { max(phoneWalkSteps, watchWalkSteps ?? 0) }
  var walkStateForWatch: WalkExchange.PhoneState {
    WalkExchange.PhoneState(request: currentWalk, steps: currentWalk == nil ? 0 : phoneWalkSteps,
      completion: lastFinishedWalk)
  }
  var feelingTitle: String { Self.feelingTitle(for: feeling) }
  nonisolated static func feelingTitle(for feeling: Double) -> String {
    if feeling < 0.33 {
      "Not great"
    } else if feeling < 0.66 {
      "Not sure yet"
    } else {
      "Pretty relieved"
    }
  }
  var feelingMascot: String { Self.feelingMascot(for: feeling) }

  static func feelingMascot(for feeling: Double) -> String {
    if feeling < 0.33 {
      "MascotWorstCase4"
    } else if feeling < 0.66 {
      "MascotStillDoubtful1"
    } else {
      "MascotBestCase1"
    }
  }
  func start(question: String = "") {
    stopCardPreparation()
    showCardGenerationIssue = false
    self.question = question
    resumedDecisionID = nil
    lens = .best
    orderCards()
    safetyConcern = nil
    lastShownConcern = nil
    index = 0
    answers = []
    walks = 0
    walkedSteps = 0
    walk = nil
    phoneWalkSteps = 0
    watchWalkSteps = nil
    clearWalkDraft()
    decision = ""
    feeling = 0.75
    lastSaved = nil
    readyAfter = .distantPast
    path = [.setup]
  }
  @discardableResult
  func resumeDecision(_ id: UUID) -> Bool {
    guard let record = savedDecisions.first(where: { $0.id == id }) else { return false }
    start(question: record.question)
    resumedDecisionID = id
    lens = record.lens ?? record.answers.first?.question.lens ?? .best
    orderCards()
    answers = record.answers
    index = cards.count - 1
    decision = record.decision
    feeling = record.feeling
    walks = record.walks
    path = [.decision]
    return true
  }

  func deleteDecision(_ id: UUID) throws {
    try persist(savedDecisions.filter { $0.id != id })
  }

  func shuffle(using generator: (any ReflectionCardGenerating)? = nil, preferCloud: Bool = false,
    startedAt: ContinuousClock.Instant = .now
  ) {
    guard path.last == .setup, canStart, safetyConcern == nil else { return }
    guard !checkSafety(automatically: false) else { return }
    showCardGenerationIssue = false
    guard let generator else {
      openCards(ReflectionQuestion.deck(for: lens), personalized: false)
      return
    }
    let dilemma = question
    let selectedLens = lens
    let preparation = ReflectionCardPreparation(
      generator: generator, question: dilemma.trimmingCharacters(in: .whitespacesAndNewlines),
      lens: selectedLens, startedAt: startedAt)
    cardPreparation = preparation
    isPreparingCards = true
    path.append(.cards)
    preparation.start(preferCloud: preferCloud) { [weak self] outcome in
      guard let self, self.isPreparingCards, self.path.last == .cards else { return }
      guard self.question == dilemma, self.lens == selectedLens, self.safetyConcern == nil else {
        self.cancelCardPreparation()
        return
      }
      self.finishCardPreparation(with: outcome)
    }
  }

  func useStandardCards() {
    guard isPreparingCards, path.last == .cards, !checkSafety(automatically: false) else { return }
    finishCardPreparation(with: .standard)
  }

  func cancelCardPreparation() {
    guard isPreparingCards else { return }
    stopCardPreparation()
    if path.last == .cards { path.removeLast() }
  }

  private func finishCardPreparation(with outcome: ReflectionCardPreparation.Outcome) {
    switch outcome {
    case .personalized(let cards):
      openCards(cards, personalized: true)
    case .standard:
      openCards(ReflectionQuestion.deck(for: lens), personalized: false)
    case .blocked, .refused:
      cancelCardPreparation()
      showCardGenerationIssue = true
    }
  }

  private func stopCardPreparation() {
    guard isPreparingCards else { return }
    cardPreparation?.cancel()
    cardPreparation = nil
    isPreparingCards = false
  }

  private func openCards(_ cards: [ReflectionQuestion], personalized: Bool) {
    self.cards = cards
    usesPersonalizedCards = personalized
    index = 0
    answers = []
    readyAfter = .distantPast
    stopCardPreparation()
    if path.last == .setup { path.append(.cards) }
  }
  func answer(_ yes: Bool) {
    guard !isPreparingCards, Date.now >= readyAfter else { return }
    let answer = ReflectionAnswer(question: currentCard, yes: yes)
    if let existing = answers.firstIndex(where: { $0.id == answer.id }) {
      answers[existing] = answer
    } else {
      answers.append(answer)
    }
    readyAfter = .now.addingTimeInterval(0.3)
    if index + 1 < cards.count { index += 1 } else { path.append(.pause) }
  }
  func ready() {
    guard !isPreparingCards, Date.now >= readyAfter else { return }
    if path.last == .returnFromWalk { clearWalkDraft() }
    path.append(.decision)
  }
  func beginWalk() {
    guard currentWalk == nil else { return }
    walkedSteps = 0
    phoneWalkSteps = 0
    watchWalkSteps = nil
    let request = WalkExchange.Request()
    walk = request
    path.append(.walk)
    saveWalkDraft(request)
  }
  func endWalk(steps: Int) {
    guard let request = currentWalk else { return }
    walk = nil
    walkedSteps = max(steps, currentWalkSteps)
    walks += 1
    lastFinishedWalk = WalkExchange.Completion(id: request.id, steps: walkedSteps)
    path.append(.returnFromWalk)
    saveWalkDraft(request, finishedSteps: walkedSteps)
  }
  func updatePhoneWalkSteps(_ steps: Int) {
    guard currentWalk != nil else { return }
    phoneWalkSteps = max(phoneWalkSteps, steps)
    if currentWalkSteps >= WalkExchange.goal { endWalk(steps: currentWalkSteps) }
  }
  func updateWalkFromWatch(_ update: WalkExchange.Update) {
    guard update.linked, currentWalk?.id == update.id else { return }
    watchWalkSteps = max(watchWalkSteps ?? 0, update.steps)
    if update.finishedAt != nil || currentWalkSteps >= WalkExchange.goal {
      endWalk(steps: currentWalkSteps)
    }
  }
  func keepReflecting() {
    guard !checkSafety(automatically: false) else { return }
    clearWalkDraft()
    index = 0
    readyAfter = .distantPast
    path = [.setup, .cards]
  }
  func saveDecision() {
    guard canSave else { return }
    let record = SavedDecision(
      id: resumedDecisionID ?? UUID(), createdAt: .now, question: question,
      decision: decision.trimmingCharacters(in: .whitespacesAndNewlines),
      feeling: feeling, answers: answers, walks: walks, lens: lens)
    do {
      try persist(savedDecisions.filter { $0.id != record.id } + [record])
      resumedDecisionID = record.id
      lastSaved = record
      path.append(.saved)
    } catch {
      saveError = error.localizedDescription
      showSaveError = true
    }
  }
  func home() {
    clearWalkDraft()
    path = []
  }

  private func persist(_ decisions: [SavedDecision]) throws {
    try FileManager.default.createDirectory(
      at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(decisions).write(to: storageURL,
      options: [.atomic, .completeFileProtection])
    savedDecisions = decisions
  }

  private func orderCards() {
    cards = ReflectionQuestion.deck(for: lens)
    usesPersonalizedCards = false
  }

  private func saveWalkDraft(_ request: WalkExchange.Request, finishedSteps: Int? = nil) {
    let draft = ReflectionWalkDraft(request: request, question: question, lens: lens, answers: answers,
      walks: walks, finishedSteps: finishedSteps, cards: usesPersonalizedCards ? cards : nil,
      cardIndex: index)
    try? FileManager.default.createDirectory(at: walkDraftURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try? JSONEncoder().encode(draft).write(to: walkDraftURL,
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  private func clearWalkDraft() {
    try? FileManager.default.removeItem(at: walkDraftURL)
  }

  /// Automatic checks avoid reopening an acknowledged sheet for every partial transcript.
  /// Starting the deck always checks again, so dismissing the sheet cannot bypass it.
  @discardableResult
  func checkSafety(automatically: Bool = true) -> Bool {
    guard let concern = SafetyScreening.concern(in: question) else {
      lastShownConcern = nil
      return false
    }
    if !automatically || lastShownConcern != concern {
      lastShownConcern = concern
      safetyConcern = concern
    }
    return true
  }
}
