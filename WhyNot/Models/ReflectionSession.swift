import Foundation
import Observation

@MainActor @Observable
final class ReflectionSession {
  var path: [ReflectionRoute] = [] {
    didSet {
      if path.last != .cards { stopCardPreparation() }
      if path.isEmpty { clearDraft() } else { saveDraft() }
    }
  }
  var question = ""
  var lens: ReflectionLens = .best
  var cards = ReflectionQuestion.deck(for: .best)
  private(set) var isPreparingCards = false
  private(set) var usesPersonalizedCards = false
  var showCardGenerationIssue = false
  var showNoNewCards = false
  var needsMoreTime = false
  var insight: ReflectionInsight?
  var index = 0
  var answers: [ReflectionAnswer] = []
  var decision = "" {
    didSet { if decision != oldValue && path.last == .decision { saveDraft() } }
  }
  var feeling = 0.75 {
    didSet { if feeling != oldValue && path.last == .decision { saveDraft() } }
  }
  var walks = 0
  var walkedSteps = 0
  private var walk: WalkExchange.Request?
  private var walkCompletions: [WalkExchange.Completion] = []
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
  private var decisionID = UUID()
  @ObservationIgnored private var lastShownConcern: SafetyConcern?
  @ObservationIgnored private let storageURL: URL
  @ObservationIgnored private let walkDraftURL: URL
  @ObservationIgnored private var cardPreparation: ReflectionCardPreparation?
  @ObservationIgnored private let onDecisionSaved: (SavedDecision) -> Void

  init(
    storageURL: URL = URL.documentsDirectory.appending(path: "decisions.json"),
    onDecisionSaved: @escaping (SavedDecision) -> Void = { _ in }
  ) {
    self.storageURL = storageURL
    self.onDecisionSaved = onDecisionSaved
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
      decisionID = draft.decisionID ?? UUID()
      decision = draft.decision ?? ""
      feeling = draft.feeling ?? 0.75
      needsMoreTime = draft.needsMoreTime ?? false
      orderCards()
      if let deck = draft.cards, isRestorableDeck(deck) {
        cards = deck
        usesPersonalizedCards = draft.personalizedCards ?? true
      }
      index = min(max(0, draft.cardIndex ?? (cards.count - 1)), cards.count - 1)

      if let restored = draft.path, !restored.isEmpty, restored.allSatisfy(\.isDraftStep) {
        path = restored
        walk = draft.request
        walkCompletions = draft.walkCompletions ?? []
      } else if let request = draft.request {
        if let steps = draft.finishedSteps {
          walkCompletions = [.init(id: request.id, steps: steps)]
          path = [.setup, .cards, .pause, .walk, .returnFromWalk]
        } else {
          walk = request
          path = [.setup, .cards, .pause, .walk]
        }
      }

      lastFinishedWalk = walkCompletions.last
      if walk == nil { walkedSteps = lastFinishedWalk?.steps ?? 0 }
    }
  }
  var currentCard: ReflectionQuestion { cards[min(index, cards.count - 1)] }
  var yesCount: Int { answers.count(where: \.yes) }
  var interpretedAnswers: ReflectionInsight { insight ?? ReflectionInsight.offline(from: answers) }
  private var followUpContext: ReflectionFollowUp {
    ReflectionFollowUp(answers: answers, seen: answers.map(\.question) + cards,
      userIsUnsure: needsMoreTime)
  }
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
    showNoNewCards = false
    insight = nil
    path = [.setup]
    needsMoreTime = false
    self.question = question
    decisionID = UUID()
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
    walkCompletions = []
    clearDraft()
    decision = ""
    feeling = 0.75
    lastSaved = nil
    readyAfter = .distantPast
  }
  @discardableResult
  func resumeDecision(_ id: UUID) -> Bool {
    guard let record = savedDecisions.first(where: { $0.id == id }) else { return false }
    start(question: record.question)
    decisionID = id
    lens = record.lens ?? record.answers.first?.question.lens ?? .best
    orderCards()
    answers = record.answers
    index = cards.count - 1
    decision = record.decision
    feeling = record.feeling
    walks = record.walks
    walkCompletions = record.walkCompletions ?? []
    walkedSteps = walkCompletions.last?.steps ?? 0
    needsMoreTime = record.isDeferred == true
    path = needsMoreTime ? [.setup, .pause] : [.decision]
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
    startCards(using: generator, preferCloud: preferCloud, startedAt: startedAt, followUp: nil)
  }

  private func startCards(using generator: (any ReflectionCardGenerating)?, preferCloud: Bool,
    startedAt: ContinuousClock.Instant, followUp: ReflectionFollowUp?
  ) {
    showCardGenerationIssue = false
    showNoNewCards = false
    guard let generator else {
      openStandardCards(followUp: followUp)
      return
    }
    let dilemma = question
    let selectedLens = lens
    let preparation = ReflectionCardPreparation(
      generator: generator, question: dilemma.trimmingCharacters(in: .whitespacesAndNewlines),
      lens: selectedLens, startedAt: startedAt, timeLimit: followUp == nil ? .seconds(5) : .seconds(10),
      followUp: followUp)
    cardPreparation = preparation
    isPreparingCards = true
    path.append(.cards)
    preparation.start(preferCloud: preferCloud) { [weak self] outcome in
      guard let self, self.isPreparingCards, self.path.last == .cards else { return }
      guard self.question == dilemma, self.lens == selectedLens, self.safetyConcern == nil else {
        self.cancelCardPreparation()
        return
      }
      self.finishCardPreparation(with: outcome, followUp: followUp)
    }
  }

  func useStandardCards() {
    guard isPreparingCards, path.last == .cards, !checkSafety(automatically: false) else { return }
    let isFollowUp = path.dropLast().last == .pause || path.dropLast().last == .returnFromWalk
    finishCardPreparation(with: .standard, followUp: isFollowUp ? followUpContext : nil)
  }

  func cancelCardPreparation() {
    guard isPreparingCards else { return }
    stopCardPreparation()
    if path.last == .cards { path.removeLast() }
  }

  private func finishCardPreparation(with outcome: ReflectionCardPreparation.Outcome,
    followUp: ReflectionFollowUp?
  ) {
    switch outcome {
    case .personalized(let cards):
      openCards(cards, personalized: true, isFollowUp: followUp != nil)
    case .standard:
      openStandardCards(followUp: followUp)
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

  private func openStandardCards(followUp: ReflectionFollowUp?) {
    let cards = followUp?.standardDeck(for: lens) ?? ReflectionQuestion.deck(for: lens)
    guard !cards.isEmpty else {
      cancelCardPreparation()
      showNoNewCards = true
      return
    }
    openCards(cards, personalized: false, isFollowUp: followUp != nil)
  }

  private func openCards(_ cards: [ReflectionQuestion], personalized: Bool, isFollowUp: Bool) {
    self.cards = cards
    usesPersonalizedCards = personalized
    index = 0
    insight = nil
    needsMoreTime = false
    if !isFollowUp { answers = [] }
    readyAfter = .distantPast
    stopCardPreparation()
    path = [.setup, .cards]
  }
  func answer(_ yes: Bool) {
    guard path.last == .cards, !isPreparingCards, Date.now >= readyAfter else { return }
    insight = nil
    let answer = ReflectionAnswer(question: currentCard, yes: yes)
    if let existing = answers.firstIndex(where: { $0.id == answer.id }) {
      answers[existing] = answer
    } else {
      answers.append(answer)
    }
    readyAfter = .now.addingTimeInterval(0.3)
    if index + 1 < cards.count {
      index += 1
      saveDraft()
    } else {
      path.append(.pause)
    }
  }
  func ready() {
    guard !isPreparingCards, Date.now >= readyAfter else { return }
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
  }
  func endWalk(steps: Int) {
    guard let request = currentWalk else { return }
    walk = nil
    walkedSteps = max(steps, currentWalkSteps)
    if walkedSteps > 0 { walks += 1 }
    let completion = WalkExchange.Completion(id: request.id, steps: walkedSteps)
    walkCompletions.append(completion)
    lastFinishedWalk = completion
    path.append(.returnFromWalk)
  }
  func updatePhoneWalkSteps(_ steps: Int) {
    guard currentWalk != nil else { return }
    phoneWalkSteps = max(phoneWalkSteps, steps)
    if currentWalkSteps >= WalkExchange.goal { endWalk(steps: currentWalkSteps) }
  }
  func updateWalkFromWatch(_ update: WalkExchange.Update) {
    guard update.linked else { return }
    guard currentWalk?.id == update.id else {
      if update.finishedAt != nil { reconcileCompletedWalks(with: [update.id: update]) }
      return
    }
    watchWalkSteps = max(watchWalkSteps ?? 0, update.steps)
    if update.finishedAt != nil || currentWalkSteps >= WalkExchange.goal {
      endWalk(steps: currentWalkSteps)
    }
  }

  func reconcileCompletedWalks(with updates: [UUID: WalkExchange.Update]) {
    guard !updates.isEmpty else { return }
    // Only newer positive totals can change an already closed walk. Counting the same walk twice
    // would inflate the number of walks when Watch Connectivity delivers a duplicate packet.
    func reconcile(_ completions: inout [WalkExchange.Completion], count: inout Int) -> Bool {
      var changed = false
      for index in completions.indices {
        let completion = completions[index]
        guard let update = updates[completion.id], update.linked, update.finishedAt != nil,
          update.steps > completion.steps
        else { continue }
        if completion.steps == 0 { count += 1 }
        completions[index] = .init(id: completion.id, steps: update.steps)
        changed = true
      }
      return changed
    }

    var updatedWalks = walkCompletions
    var updatedCount = walks
    if reconcile(&updatedWalks, count: &updatedCount) {
      walkCompletions = updatedWalks
      walks = updatedCount
      if currentWalk == nil { walkedSteps = updatedWalks.last?.steps ?? 0 }
      if let id = lastFinishedWalk?.id, let completion = updatedWalks.first(where: { $0.id == id }) {
        lastFinishedWalk = completion
      }
      saveDraft()
    }

    var changedRecords = savedDecisions
    for index in changedRecords.indices {
      guard var completions = changedRecords[index].walkCompletions else { continue }
      if reconcile(&completions, count: &changedRecords[index].walks) {
        changedRecords[index].walkCompletions = completions
      }
    }
    guard changedRecords != savedDecisions else { return }
    do {
      try persist(changedRecords)
      if let id = lastSaved?.id { lastSaved = changedRecords.first { $0.id == id } }
    } catch {
      // The Watch completion remains in PhoneWatchLink history for reconciliation on relaunch.
    }
  }

  func keepReflecting(using generator: (any ReflectionCardGenerating)? = nil) {
    guard safetyConcern == nil, !checkSafety(automatically: false),
      path.last == .pause || path.last == .returnFromWalk
    else { return }
    startCards(using: generator, preferCloud: false, startedAt: .now, followUp: followUpContext)
  }

  func sleepOnIt() {
    guard path.last == .pause || path.last == .returnFromWalk,
      safetyConcern == nil, !checkSafety(automatically: false)
    else { return }
    storeReflection(deferred: true)
  }

  func saveDecision() {
    guard canSave else { return }
    storeReflection(deferred: false)
  }

  func retrySave() {
    if path.last == .pause || path.last == .returnFromWalk { sleepOnIt() } else { saveDecision() }
  }

  private func storeReflection(deferred: Bool) {
    let record = SavedDecision(
      id: decisionID, createdAt: .now, question: question,
      decision: deferred ? "" : decision.trimmingCharacters(in: .whitespacesAndNewlines),
      feeling: feeling, answers: answers, walks: walks, lens: lens, isDeferred: deferred ? true : nil,
      walkCompletions: walkCompletions.isEmpty ? nil : walkCompletions)
    do {
      try persist(savedDecisions.filter { $0.id != record.id } + [record])
      lastSaved = record
      clearDraft()
      onDecisionSaved(record)
      path.append(deferred ? .deferred : .saved)
    } catch {
      saveError = error.localizedDescription
      showSaveError = true
    }
  }
  func home() { path = [] }

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

  private func isRestorableDeck(_ deck: [ReflectionQuestion]) -> Bool {
    if ReflectionQuestion.isRestorableInitialDeck(deck, for: lens) { return true }
    return (1...4).contains(deck.count) && Set(deck.map(\.id)).count == deck.count
      && deck.allSatisfy { $0.id >= 1000 && ReflectionQuestion.isYesNoQuestion($0.text) }
  }

  private func saveDraft() {
    // Keep the previous checkpoint until a proposed deck is ready. Never restore a model request.
    guard !isPreparingCards, let step = path.last, step != .setup,
      path.allSatisfy(\.isDraftStep)
    else { return }
    let draft = ReflectionWalkDraft(request: currentWalk, question: question, lens: lens,
      answers: answers, walks: walks, finishedSteps: nil, cards: cards, cardIndex: index,
      personalizedCards: usesPersonalizedCards, path: path, decisionID: decisionID,
      decision: decision, feeling: feeling, needsMoreTime: needsMoreTime,
      walkCompletions: walkCompletions)
    try? FileManager.default.createDirectory(at: walkDraftURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try? JSONEncoder().encode(draft).write(to: walkDraftURL,
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  private func clearDraft() {
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
