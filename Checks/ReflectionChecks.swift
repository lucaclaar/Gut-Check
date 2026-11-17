import Foundation

@main struct ReflectionChecks {
  @MainActor static func main() async throws {
    try SafetyChecks.run()
    let directory = URL.temporaryDirectory.appending(path: "whynot-checks-\(UUID())")
    let file = directory.appending(path: "decisions.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = ReflectionSession(storageURL: file)
    model.start()
    model.question = " \n "
    model.shuffle()
    precondition(model.path == [.setup], "Empty questions must not enter the deck")
    model.question = "Should I take the job in Barcelona?"
    model.lens = .mixed
    model.shuffle()
    precondition(model.cards.first?.lens == .mixed && Set(model.cards.map(\.id)).count == 6)
    model.answer(true)
    model.answer(false)
    model.ready()
    precondition(
      model.answers.count == 1 && model.index == 1 && model.path.last == .cards,
      "The 300ms swipe guard must reject duplicate answers and Ready")
    try await Task.sleep(for: .milliseconds(320))
    model.ready()
    precondition(model.path.last == .decision)
    model.path.removeLast()
    precondition(
      model.index == 1 && model.answers.count == 1,
      "Back must preserve the current card and answers")
    for answer in [false, true, true, true, true] {
      model.answer(answer)
      try await Task.sleep(for: .milliseconds(320))
    }
    precondition(model.path.last == .pause && model.yesCount == 5 && model.noCount == 1)
    model.beginWalk()
    model.endWalk(steps: 820)
    precondition(model.walks == 1 && model.walkedSteps == 820 && model.path.last == .returnFromWalk)
    model.feeling = 0.1
    precondition(model.feelingTitle == "Not great" && model.feelingMascot == "MascotWorstCase4")
    model.feeling = 0.5
    precondition(model.feelingTitle == "Not sure yet")
    model.feeling = 0.75
    precondition(model.feelingTitle == "Pretty relieved")
    model.decision = " \n "
    model.saveDecision()
    precondition(model.lastSaved == nil, "An empty decision must not save")
    model.decision = "I'm taking the job in Barcelona."
    model.saveDecision()
    precondition(!model.showSaveError && model.lastSaved != nil && model.path.last == .saved)
    let reloaded = ReflectionSession(storageURL: file)
    precondition(
      reloaded.savedDecisions.count == 1 && reloaded.savedDecisions[0].answers.count == 6
        && reloaded.savedDecisions[0].decision == model.decision,
      "Saved decisions must survive a new session")
    print(
      "PASS: empty inputs, lens ordering, 300ms guard, back navigation, six answers, walk return, three feelings, atomic persistence and reload"
    )
  }
}
