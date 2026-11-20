import Foundation

@main struct ReflectionChecks {
  @MainActor static func main() async throws {
    try SafetyChecks.run()
    try TurboChecks.run()
    let directory = URL.temporaryDirectory.appending(path: "whynot-checks-\(UUID())")
    let file = directory.appending(path: "decisions.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try await ReflectionGenerationChecks.run(in: directory)
    let model = ReflectionSession(storageURL: file)
    model.start()
    precondition(model.question.isEmpty && !model.canStart)
    for lens in ReflectionLens.allCases {
      let cards = ReflectionQuestion.deck(for: lens)
      precondition(cards.count == 6 && Set(cards.map(\.id)).count == cards.count)
      if lens != .mixed { precondition(cards.allSatisfy { $0.lens == lens }) }
      let practice = ReflectionQuestion.practice(for: lens)
      precondition(practice.lens == lens && !cards.contains { $0.id == practice.id })
    }
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

    let pairedFile = directory.appending(path: "paired-decisions.json")
    let paired = ReflectionSession(storageURL: pairedFile)
    paired.beginWalk()
    let firstWalk = paired.currentWalk!
    precondition(WalkExchange.Request(payload: firstWalk.payload) == firstWalk)
    paired.endWalk(steps: 320)
    paired.beginWalk()
    let secondWalk = paired.currentWalk!
    let late = WalkExchange.Update(request: firstWalk, linked: true, steps: 2_000, finishedAt: .now)
    paired.updateWalkFromWatch(late)
    precondition(paired.currentWalk == secondWalk && paired.walks == 1)
    paired.updatePhoneWalkSteps(420)
    let progress = WalkExchange.Update(request: secondWalk, linked: true, steps: 550)
    paired.updateWalkFromWatch(progress)
    paired.updateWalkFromWatch(.init(request: secondWalk, linked: true, steps: 500))
    precondition(paired.currentWalkSteps == 550, "Both devices count some of the same steps")
    let reopened = ReflectionSession(storageURL: pairedFile)
    precondition(reopened.currentWalk == secondWalk, "A linked walk must survive relaunch")
    let completed = WalkExchange.Update(request: secondWalk, linked: true, steps: 2_000, finishedAt: .now)
    precondition(WalkExchange.Update(payload: completed.payload) == completed)
    precondition(completed.merging(progress) == completed)
    reopened.updateWalkFromWatch(completed)
    reopened.updateWalkFromWatch(completed)
    precondition(reopened.currentWalk == nil && reopened.walks == 2
      && reopened.walkedSteps == 2_000 && reopened.path.last == .returnFromWalk)
    let restoredResult = ReflectionSession(storageURL: pairedFile)
    precondition(restoredResult.path.last == .returnFromWalk && restoredResult.walkedSteps == 2_000)
    paired.updateWalkFromWatch(completed)
    precondition(paired.currentWalk == nil && paired.walks == 2
      && paired.walkedSteps == 2_000 && paired.path.last == .returnFromWalk)
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
    let reflection = reloaded.savedDecisions[0]
    let olderPick = SavedTurboDecision(id: UUID(), createdAt: reflection.createdAt.addingTimeInterval(-5),
      choice: "Older pick", options: [], decidedIn: 5, feeling: 0.75)
    let newerPick = SavedTurboDecision(id: UUID(), createdAt: reflection.createdAt.addingTimeInterval(5),
      choice: "Newer pick", options: [], decidedIn: 6, feeling: 0.5)
    let recent = RecentDecision.newestFirst(reflect: [reflection], turbo: [newerPick, olderPick])
    precondition(recent.map(\.id) == [newerPick.id, reflection.id, olderPick.id],
      "Waiting for you must include all decisions across both modes, newest first")
    precondition(reloaded.resumeDecision(reflection.id) && reloaded.path == [.decision]
      && reloaded.decision == reflection.decision && reloaded.answers == reflection.answers)
    reloaded.decision = "Revisited the choice."
    reloaded.saveDecision()
    precondition(reloaded.savedDecisions.count == 1 && reloaded.lastSaved?.id == reflection.id)
    try reloaded.deleteDecision(reflection.id)
    precondition(ReflectionSession(storageURL: file).savedDecisions.isEmpty)
    print(
      "PASS: empty inputs, lens ordering, 300ms guard, back navigation, six answers, walk return, three feelings, atomic persistence and reload"
    )
  }
}
