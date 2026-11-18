import Foundation
import Observation

@MainActor @Observable
final class ReflectionSession {
  var path: [ReflectionRoute] = []
  var question = "Should I take the job in Barcelona?"
  var lens: ReflectionLens = .best
  var cards = ReflectionQuestion.all
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
  var safetyConcern: SafetyConcern?
  @ObservationIgnored private var lastShownConcern: SafetyConcern?
  @ObservationIgnored private let storageURL: URL
  @ObservationIgnored private let walkDraftURL: URL

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
      index = max(0, cards.count - 1)
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
  var feelingMascot: String {
    if feeling < 0.33 {
      "MascotWorstCase4"
    } else if feeling < 0.66 {
      "MascotStillDoubtful1"
    } else {
      "MascotBestCase1"
    }
  }
  func start() {
    safetyConcern = nil
    lastShownConcern = nil
    index = 0
    answers = []
    walks = 0
    walkedSteps = 0
    walk = nil
    clearWalkDraft()
    decision = ""
    feeling = 0.75
    lastSaved = nil
    readyAfter = .distantPast
    path = [.setup]
  }
  func shuffle() {
    guard canStart else { return }
    guard !checkSafety(automatically: false) else { return }
    orderCards()
    index = 0
    answers = []
    path.append(.cards)
  }
  func answer(_ yes: Bool) {
    guard Date.now >= readyAfter else { return }
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
    guard Date.now >= readyAfter else { return }
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
      id: UUID(), createdAt: .now, question: question,
      decision: decision.trimmingCharacters(in: .whitespacesAndNewlines),
      feeling: feeling, answers: answers, walks: walks)
    do {
      let next = savedDecisions + [record]
      let data = try JSONEncoder().encode(next)
      try FileManager.default.createDirectory(
        at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
      savedDecisions = next
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

  private func orderCards() {
    cards = ReflectionQuestion.all.filter { $0.lens == lens }
      + ReflectionQuestion.all.filter { $0.lens != lens }
  }

  private func saveWalkDraft(_ request: WalkExchange.Request, finishedSteps: Int? = nil) {
    let draft = ReflectionWalkDraft(request: request, question: question, lens: lens, answers: answers,
      walks: walks, finishedSteps: finishedSteps)
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
