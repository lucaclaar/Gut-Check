import Foundation

enum TurboChecks {
  static func run() throws {
    let folder = URL.temporaryDirectory.appending(path: "turbo-checks-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "turbo-decisions.json")
    try checkRules()
    try checkOptions(file)
    try checkRound(file)
    try checkEndings(file)
    try checkFeelingAndRunnerUp(file)
    try checkDraftsAndPersistence(folder, file)
    checkBubbleMotion()
    print("Turbo checks passed: options and repeats, spread timers, unlimited taps up to a full bubble, fixed round, endings and tie, pause/resume, runner-up, drafts and persistence")
  }

  private static func session(_ file: URL, _ texts: [String]) -> TurboSession {
    let model = TurboSession(storageURL: file)
    model.options = texts.map { TurboOption(text: $0) }
    return model
  }

  /// Starts a round and skips the 3-2-1 countdown, returning the time play began.
  @discardableResult
  private static func play(_ model: TurboSession, seed: UInt64 = 17, at start: Double = 0) -> Double {
    var random = TestRandom(state: seed)
    precondition(model.start(using: &random) && model.phase == .countdown && model.countdownNumber == 3)
    model.tick(at: start)
    model.tick(at: start + 3)
    precondition(model.phase == .playing && model.elapsed == 0)
    return start + 3
  }

  private static func checkRules() throws {
    let rules = TurboRules()
    precondition(rules.round == 15 && rules.shortestTimer == 3 && rules.longestTimer == 12
      && rules.tapBonus == 1 && rules.maximumTimer == 12 && rules.lastSecondWindow == 2)
    let short = TurboRules(round: 10)
    precondition(short.tapBonus == 0.5 && short.maximumTimer == 8 && short.lastSecondWindow == 1.5)
  }

  private static func checkOptions(_ file: URL) throws {
    let model = TurboSession(storageURL: file)
    precondition(model.options.count == 3 && model.filledOptions.isEmpty && !model.hasTypedOptions)
    model.options = [TurboOption(text: "Tacos"), TurboOption(text: "Sushi")]
    precondition(!model.start() && model.validationMessage == "Add at least 3 options to start.")
    model.options.append(TurboOption(text: "  sushi "))
    let repeated = model.options[2].id
    precondition(model.repeatedOptions == [repeated: "Sushi"],
      "Only the later entry is flagged, and the message names the option already on the list")
    precondition(!model.start() && model.validationMessage == "Change the repeated option to start.")
    model.options[2].text = "Súshi"
    precondition(model.repeatedOptions[repeated] == "Sushi", "Accents don't make options different")
    model.options[2].text = "Pizza"
    precondition(model.repeatedOptions.isEmpty && model.canStart)
    let blank = model.addOption()!
    precondition(model.addOption() == blank, "A blank field is reused before adding another")
    model.removeOption(blank)
    precondition(model.options.count == 3 && !model.options.contains { $0.id == blank })
    model.setOptionText("Late edit", for: blank)
    precondition(model.filledOptions.map(\.text) == ["Tacos", "Sushi", "Pizza"],
      "A removed field must ignore delayed text edits")
    let third = model.options[2].id
    model.removeOption(third)
    precondition(model.options.count == 3 && model.options[2].id == third && !model.canStart,
      "Clearing a required slot keeps its identity and disables Start")
    model.options[2].text = "Pizza"
    model.options[0].text = "I want to kill myself"
    precondition(!model.start(), "Unsafe options must never enter the game")
    model.options = (1...6).map { TurboOption(text: "Option \($0)") }
    precondition(model.addOption() == nil)
    model.options.append(TurboOption(text: "Seven"))
    precondition(!model.start() && model.validationMessage == "Use at most 6 options.")
  }

  private static func checkRound(_ file: URL) throws {
    // Hidden timers: spread between 3 and 12 s, all different, and not in typing order every time.
    var orders: Set<[Double]> = []
    for count in 3...6 {
      for seed in UInt64(1)...12 {
        let model = session(file, (1...count).map { "Option \($0)" })
        play(model, seed: seed)
        let timers = model.timers
        precondition(timers.count == count && Set(timers).count == count, "Every option gets its own timer")
        precondition(timers.allSatisfy { (2.4...12).contains($0) })
        precondition(timers.sorted().last! - timers.sorted().first! >= 7, "Timers must be clearly spread out")
        if count == 4 { orders.insert(timers) }
      }
    }
    precondition(orders.count > 1, "Timers must be shuffled between rounds")

    // Countdown blocks taps; every tap adds 1 s, as many times as the person likes, up to a full bubble.
    let model = session(file, ["Tacos", "Sushi", "Pizza"])
    var random = TestRandom()
    precondition(model.start(using: &random))
    let first = model.bubbles[0].id
    model.tick(at: 100)
    precondition(model.save(first, at: 100) == .ignored && model.bubbles[0].taps == 0,
      "Tapping must not skip the countdown")
    model.tick(at: 101)
    precondition(model.phase == .countdown && model.countdownNumber == 2)
    model.tick(at: 103)
    precondition(model.phase == .playing && model.remaining == 15)
    let startLeft = model.timeLeft[0]
    model.tick(at: 104)
    precondition(abs(model.timeLeft[0] - (startLeft - 1)) < 1e-9)
    let before = model.timeLeft
    let saved = model.save(first, at: 104)
    precondition(abs(model.timeLeft[0] - min(12, before[0] + 1)) < 1e-9 && model.bubbles[0].taps == 1,
      "A tap adds 1 s")
    precondition(saved == .saved(lastSecond: before[0] <= 2))
    precondition(Array(model.timeLeft.dropFirst()) == Array(before.dropFirst()),
      "Tapping one option must not change the others")
    for _ in 0..<20 { model.save(first, at: 104) }
    precondition(model.bubbles[0].taps == 21 && model.timeLeft[0] == 12 && model.reserves[0] == 1,
      "Twenty taps fill the bubble to the top and every tap counts")
    precondition(model.save(first, at: 104) == .full && model.bubbles[0].taps == 22,
      "A tap on a full bubble adds no time but still counts as a tap")

    // Pause freezes everything; resuming plays a fresh 3-2-1 first.
    model.pause(at: 105)
    let paused = model.timeLeft
    model.tick(at: 1000)
    precondition(model.phase == .paused && model.elapsed == 2 && model.timeLeft == paused)
    model.resume(at: 1010)
    model.tick(at: 1012)
    precondition(model.phase == .countdown && model.countdownNumber == 1 && model.timeLeft == paused)
    model.tick(at: 1014)
    precondition(model.phase == .playing && model.elapsed == 3,
      "Countdown and background time must not drain the timers")

    // Endless tapping can never make the round longer than 15 s.
    let mash = session(file, ["One", "Two", "Three"])
    let t0 = play(mash)
    var time = t0
    while mash.phase == .playing && time < t0 + 40 {
      for bubble in mash.activeBubbles { mash.save(bubble.id, at: time) }
      time += 0.25
      mash.tick(at: time)
    }
    precondition(mash.phase != .playing && mash.elapsed <= 15, "The round has a hard end")

    // A slow frame gives the same result as many small ones.
    let dense = session(file, ["A", "B", "C", "D"])
    let sparse = session(file, ["A", "B", "C", "D"])
    play(dense)
    play(sparse)
    for step in 1...36 { dense.tick(at: 3 + Double(step) * 0.25) }
    sparse.tick(at: 12)
    precondition(dense.phase == sparse.phase && dense.elapsed == sparse.elapsed
      && dense.bubbles.map(\.isPopped) == sparse.bubbles.map(\.isPopped)
      && zip(dense.timeLeft, sparse.timeLeft).allSatisfy { abs($0 - $1) < 1e-9 })
  }

  private static func checkEndings(_ file: URL) throws {
    // Nobody saves or lets go: options pop in timer order and the round ends with no pick.
    let idle = session(file, ["Tacos", "Sushi", "Pizza"])
    let t0 = play(idle)
    let order = idle.bubbles.sorted { idle.timers[$0.slot] < idle.timers[$1.slot] }
    idle.tick(at: t0 + 14)
    precondition(idle.phase == .timedOut && idle.chosen == nil && idle.outcome == nil,
      "A round where nothing was saved or let go ends in Time's up")
    precondition(idle.bubbles.first { $0.id == order[0].id }?.endedAt == idle.timers[order[0].slot],
      "An option disappears exactly when its timer reaches zero")
    precondition(idle.elapsed == idle.timers[order[1].slot], "The round ends the moment one option is left")

    // One save is enough for the last one standing to win.
    let saved = session(file, ["Tacos", "Sushi", "Pizza"])
    let ts = play(saved)
    let first = saved.bubbles.min { saved.timers[$0.slot] < saved.timers[$1.slot] }!
    saved.save(first.id, at: ts + 0.1)
    saved.tick(at: ts + 20)
    precondition(saved.phase == .picked && saved.outcome == .lastStanding)

    // Hold to pick.
    let held = session(file, ["Tacos", "Sushi", "Pizza"])
    let t1 = play(held)
    held.choose(held.bubbles[1].id, at: t1 + 1)
    precondition(held.phase == .picked && held.outcome == .held && held.chosen?.text == "Sushi")

    // A let-go option never comes back.
    let gone = session(file, ["Tacos", "Sushi", "Pizza"])
    let t2 = play(gone)
    gone.discard(gone.bubbles[0].id, at: t2 + 0.5)
    gone.discard(gone.bubbles[1].id, at: t2 + 0.6)
    precondition(gone.phase == .picked && gone.chosen?.text == "Pizza" && gone.bubbles[0].isDiscarded)

    // Time up with several left: the option tapped most wins; equal taps ask the person to pick.
    let rules = TurboRules(round: 15)
    for tie in [false, true] {
      let model = session(file, ["Tacos", "Sushi", "Pizza", "Ramen"])
      let start = play(model)
      let keep = Array(model.bubbles.prefix(2)).map(\.id)
      if !tie { model.save(keep[0], at: start) }
      var time = start
      while model.phase == .playing {
        for id in keep { model.save(id, at: time) }
        time += 0.5
        model.tick(at: time)
      }
      let taps = keep.map { id in model.bubbles.first { $0.id == id }!.taps }
      precondition(Set(model.activeBubbles.map(\.id)) == Set(keep) && model.elapsed == rules.round,
        "Tapped options outlast the round, untouched ones pop")
      if tie {
        precondition(taps[0] == taps[1] && model.phase == .tie && Set(model.tiedBubbles.map(\.id)) == Set(keep))
        model.breakTie(keep[1])
        precondition(model.phase == .picked && model.outcome == .tieBreak && model.chosen?.id == keep[1])
      } else {
        precondition(taps[0] == taps[1] + 1 && model.phase == .picked && model.outcome == .mostSaves
          && model.chosen?.id == keep[0])
      }
    }

    // Tapping the option you want makes it the final pick: the others pop, it stays.
    let favorite = session(file, ["Tacos", "Sushi", "Pizza", "Ramen"])
    let tf = play(favorite)
    let shortest = favorite.bubbles.min { favorite.timers[$0.slot] < favorite.timers[$1.slot] }!
    var clock = tf
    while favorite.phase == .playing {
      favorite.save(shortest.id, at: clock)
      clock += 0.5
      favorite.tick(at: clock)
    }
    precondition(favorite.phase == .picked && favorite.chosen?.id == shortest.id,
      "Even the fastest option wins when it is the one being tapped")

    // Everything pops or is let go: no pick.
    let none = session(file, ["Tacos", "Sushi", "Pizza"])
    let t3 = play(none)
    for bubble in none.bubbles { none.discard(bubble.id, at: t3 + 1) }
    precondition(none.phase != .playing)
    let empty = session(file, ["Tacos", "Sushi", "Pizza"])
    let t4 = play(empty)
    empty.discard(empty.bubbles[0].id, at: t4 + 0.1)
    empty.tick(at: t4 + 20)
    precondition(empty.phase == .picked && empty.outcome == .lastStanding)
  }

  private static func checkFeelingAndRunnerUp(_ file: URL) throws {
    let model = session(file, ["Tacos", "Sushi", "Pizza", "Ramen"])
    let t0 = play(model)
    let pizza = model.bubbles[2].id
    let ramen = model.bubbles[3].id
    model.save(pizza, at: t0 + 0.2)
    model.save(pizza, at: t0 + 0.3)
    model.save(pizza, at: t0 + 0.4)
    model.save(model.bubbles[0].id, at: t0 + 0.5)
    model.choose(ramen, at: t0 + 1)
    precondition(model.phase == .picked && model.runnerUp?.id == pizza,
      "The runner-up is the option tapped most")
    model.continueToFeeling()
    precondition(model.phase == .feeling && model.feeling == 0.5, "The slider starts neutral")
    model.returnToResult()
    precondition(model.phase == .picked)
    model.continueToFeeling()
    model.feeling = 0.1
    model.confirmFeeling()
    precondition(model.reviewingPick && model.lastSaved == nil, "Not great suggests the runner-up first")
    model.backToFeeling()
    precondition(!model.reviewingPick)
    model.confirmFeeling()
    model.chooseRunnerUp()
    precondition(model.phase == .feeling && model.needsAlternativeFeeling && model.lastSaved == nil
      && model.finalChoice?.id == pizza && model.feeling == 0.1,
      "Switching asks how the runner-up feels before saving")
    model.saveDecision()
    model.confirmFeeling()
    precondition(model.phase == .feeling && model.needsAlternativeFeeling && model.lastSaved == nil,
      "Neither save path can confirm the runner-up until it is explicitly rated")
    model.rateAlternative(0.75)
    precondition(model.phase == .feeling && !model.needsAlternativeFeeling && model.lastSaved == nil,
      "Rating the runner-up enables confirmation without saving automatically")
    model.confirmFeeling()
    precondition(model.phase == .saved && model.lastSaved?.choice == "Pizza" && model.lastSaved?.feeling == 0.75
      && model.lastSaved?.gutPick == "Ramen" && model.switchedFromGut,
      "The saved feeling is about the final choice")
    model.saveDecision()
    precondition(model.savedDecisions.count == 1, "Saving twice must not duplicate the round")

    // Keeping the pick, and a pick that feels fine, both save straight away.
    let keep = session(file, ["Tacos", "Sushi", "Pizza"])
    let t1 = play(keep)
    keep.save(keep.bubbles[0].id, at: t1 + 0.1)
    keep.choose(keep.bubbles[1].id, at: t1 + 0.2)
    keep.continueToFeeling()
    keep.feeling = 0.2
    keep.confirmFeeling()
    keep.keepOriginalPick()
    precondition(keep.phase == .saved && keep.lastSaved?.choice == "Sushi" && keep.lastSaved?.gutPick == nil)
    let fine = session(file, ["Tacos", "Sushi", "Pizza"])
    let t2 = play(fine)
    fine.choose(fine.bubbles[0].id, at: t2 + 0.2)
    fine.continueToFeeling()
    fine.feeling = 0.8
    fine.confirmFeeling()
    precondition(fine.phase == .saved && !fine.reviewingPick)

    // Let-go options are never suggested; with no taps the longest-lasting one is.
    let quiet = session(file, ["Tacos", "Sushi", "Pizza", "Ramen"])
    let t3 = play(quiet)
    let order = quiet.bubbles.sorted { quiet.timers[$0.slot] < quiet.timers[$1.slot] }
    quiet.discard(order[3].id, at: t3 + 0.1)
    quiet.tick(at: t3 + 14)
    precondition(quiet.chosen?.id == order[2].id && quiet.runnerUp?.id == order[1].id)
  }

  private static func checkDraftsAndPersistence(_ folder: URL, _ file: URL) throws {
    try? FileManager.default.removeItem(at: file)
    // Save for later from a paused round keeps the options, not the timers.
    let model = session(file, ["Tacos", "Sushi", "Pizza", "Ramen"])
    let t0 = play(model)
    model.pause(at: t0 + 2)
    precondition(model.saveForLater() && model.phase == .setup && model.filledOptions.isEmpty)
    var reloaded = TurboSession(storageURL: file)
    let draft = reloaded.savedDecisions.first!
    precondition(draft.isUnfinished && draft.title == "Tacos · Sushi · Pizza · Ramen")
    precondition(reloaded.resumeDecision(draft.id)
      && reloaded.filledOptions.map(\.text) == ["Tacos", "Sushi", "Pizza", "Ramen"])
    let t1 = play(reloaded, seed: 5)
    reloaded.choose(reloaded.bubbles[0].id, at: t1 + 0.5)
    reloaded.continueToFeeling()
    reloaded.feeling = 0.9
    reloaded.confirmFeeling()
    precondition(reloaded.savedDecisions.count == 1 && reloaded.lastSaved?.id == draft.id
      && reloaded.savedDecisions[0].isUnfinished == false, "Finishing a resumed decision replaces its draft")

    // Discarding a resumed draft removes it.
    let options = session(file, ["Yes", "No", "Maybe"])
    precondition(options.saveForLater())
    reloaded = TurboSession(storageURL: file)
    let second = reloaded.savedDecisions.first { $0.isUnfinished }!
    precondition(reloaded.resumeDecision(second.id))
    try reloaded.discardCurrent()
    precondition(TurboSession(storageURL: file).savedDecisions.allSatisfy { !$0.isUnfinished })
    precondition(!TurboSession(storageURL: file).saveForLater(), "Nothing typed means nothing to save")

    // Records written by the earlier Turbo still load.
    let legacy = folder.appending(path: "legacy.json")
    let json = """
      [{"id":"6E1B1D1E-0F0E-4C55-9A8E-1D2C3B4A5F60","createdAt":0,"choice":"Sushi","decidedIn":7,"feeling":0.8,
      "options":[{"id":"6E1B1D1E-0F0E-4C55-9A8E-1D2C3B4A5F61","text":"Sushi","slot":0,"rescues":2,"isPopped":false,"lastRescuedAt":3}]}]
      """
    try Data(json.utf8).write(to: legacy)
    let old = TurboSession(storageURL: legacy).savedDecisions
    precondition(old.count == 1 && old[0].options[0].taps == 2 && !old[0].isUnfinished && old[0].title == "Sushi")

    // A failed write stays on the feeling screen with an error.
    let blocked = folder.appending(path: "not-a-folder")
    try Data().write(to: blocked)
    let failure = session(blocked.appending(path: "record.json"), ["One", "Two", "Three"])
    let t2 = play(failure)
    failure.choose(failure.bubbles[0].id, at: t2 + 1)
    failure.continueToFeeling()
    failure.confirmFeeling()
    precondition(failure.phase == .feeling && failure.lastSaved == nil && failure.saveError != nil)
  }

  private struct TestRandom: RandomNumberGenerator {
    var state: UInt64 = 17

    mutating func next() -> UInt64 {
      state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
      return state
    }
  }

  private static func checkBubbleMotion() {
    let ringAllowance: CGFloat = 14
    for size in [CGSize(width: 272, height: 230), CGSize(width: 354, height: 440)] {
      for count in 3...6 {
        var motion = TurboBubbleMotion(size: size, count: count, ringAllowance: ringAllowance)
        let slots = Array(0..<count)
        let start = motion.centers
        let outerDiameter = motion.diameter + ringAllowance
        var touchedNeighbor = false
        for frame in 0..<540 {
          let drag: (slot: Int, target: CGPoint)? = switch frame {
          case 0..<140: nil
          case 140..<260: (0, start[1])
          case 260..<380: (0, CGPoint(x: size.width, y: size.height))
          default: nil
          }
          motion.advance(to: Double(frame) / 60, activeSlots: slots, drag: drag, reduceMotion: false)
          for (slot, center) in motion.centers.enumerated() {
            let radius = outerDiameter / 2
            precondition((radius...(size.width - radius)).contains(center.x)
              && (radius...(size.height - radius)).contains(center.y), "Keep bubbles inside the arena")
            for other in motion.centers.dropFirst(slot + 1) {
              let distance = hypot(center.x - other.x, center.y - other.y)
              precondition(distance >= outerDiameter - 1e-8, "Bubbles must never overlap")
              if slot == 0 && drag != nil && distance < outerDiameter + 1 {
                touchedNeighbor = true
              }
            }
          }
        }
        precondition(touchedNeighbor, "Bubbles must be able to make contact while dragging")
        motion.advance(to: 10, activeSlots: slots, drag: nil, reduceMotion: true)
        precondition(motion.centers == start, "Reduce Motion must keep resting bubbles still")
      }
    }
  }
}
