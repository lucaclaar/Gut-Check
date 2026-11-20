import Foundation

enum TurboChecks {
  static func run() throws {
    let folder = URL.temporaryDirectory.appending(path: "turbo-checks-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "turbo-decisions.json")
    let model = TurboSession(storageURL: file)
    precondition(model.options.count == 3 && model.filledOptions.isEmpty)
    model.options = [TurboOption(text: "One"), TurboOption(text: "Two")]
    precondition(!model.start(), "At least three options are required")
    model.options.append(TurboOption(text: " one "))
    precondition(!model.start() && model.duplicateOptionIDs.count == 2,
      "Names must be distinct after trimming/case folding")
    model.options[2].text = "Three"
    let blank = model.addOption()!
    precondition(model.addOption() == blank && model.plannedSeconds == 9,
      "A blank field must not inflate the timer")
    model.removeOption(blank)
    precondition(model.options.count == 3 && !model.options.contains { $0.id == blank })
    model.setOptionText("Late edit", for: blank)
    precondition(model.optionText(for: blank).isEmpty
      && model.filledOptions.map(\.text) == ["One", "Two", "Three"],
      "A removed field must ignore delayed text edits")
    let third = model.options[2].id
    model.removeOption(third)
    precondition(model.options.count == 3 && model.options[2].id == third
      && model.options[2].text.isEmpty && !model.canStart,
      "Clearing a required slot must keep its identity and disable Start")
    model.options[2].text = "Three"
    model.options[0].text = "I want to kill myself"
    precondition(!model.start(), "Unsafe options must never enter the game")
    model.options[0].text = "One"

    precondition(model.start() && model.phase == .countdown
      && model.countdownNumber == 3 && model.remaining == 9)
    let first = model.bubbles[0].id
    let second = model.bubbles[1].id
    model.tick(at: 100)
    model.rescue(first, at: 100)
    precondition(model.bubbles[0].rescues == 0, "Tapping must not skip the countdown")
    model.tick(at: 101)
    precondition(model.phase == .countdown && model.countdownNumber == 2)
    model.tick(at: 102)
    precondition(model.phase == .countdown && model.countdownNumber == 1)
    model.tick(at: 103)
    precondition(model.phase == .playing && model.remaining == 9 && model.reserves == [1, 1, 1])
    model.rescue(first, at: 103)
    model.tick(at: 105)
    let drained = model.reserves[0]
    let beforeNeighbors = Array(model.reserves.dropFirst())
    precondition(Set(model.reserves).count == 3, "Each bubble must drain at a different rate")
    model.rescue(first, at: 105)
    model.rescue(first, at: 105.1)
    precondition(model.reserves[0] > drained + 0.13 && model.bubbles[0].rescues == 3,
      "Fast taps must refill the same bubble independently")
    precondition(zip(model.reserves.dropFirst(), beforeNeighbors).allSatisfy { $0 <= $1 },
      "Refilling one bubble must not refill its neighbors")

    model.pause(at: 106)
    let pausedReserves = model.reserves
    model.tick(at: 1000)
    precondition(model.phase == .paused && model.elapsed == 3 && model.reserves == pausedReserves)
    model.resume(at: 1010)
    model.tick(at: 1012)
    precondition(model.phase == .countdown && model.countdownNumber == 1 && model.reserves == pausedReserves)
    model.tick(at: 1014)
    precondition(model.phase == .playing && model.elapsed == 4,
      "Countdown and background time must not drain the reserves")
    model.choose(second, at: 1014)
    precondition(model.phase == .picked && model.chosen?.text == "Two")
    model.continueToFeeling()
    model.returnToResult()
    precondition(model.phase == .picked)
    model.continueToFeeling()
    model.feeling = 0.1
    model.reviewPick()
    precondition(model.reviewingPick && model.suggestedAlternative?.id == first)
    model.chooseAlternative(first)
    precondition(model.hasReviewedPick && model.finalChoice?.id == first && model.needsAlternativeFeeling)
    model.saveDecision()
    precondition(model.lastSaved == nil && model.phase == .feeling)
    model.rateAlternative(0.75)
    precondition(!model.needsAlternativeFeeling && model.feeling == 0.75)
    model.saveDecision()
    model.saveDecision()
    precondition(model.phase == .saved && model.savedDecisions.count == 1 && model.saveError == nil)
    let reloaded = TurboSession(storageURL: file)
    precondition(reloaded.savedDecisions.first?.choice == "One"
      && reloaded.savedDecisions.first?.options.first?.rescues == 3
      && reloaded.savedDecisions.first?.feeling == 0.75)
    let savedID = reloaded.savedDecisions[0].id
    precondition(reloaded.resumeDecision(savedID) && reloaded.filledOptions.map(\.text) == ["One", "Two", "Three"])
    precondition(reloaded.start())
    reloaded.tick(at: 0)
    reloaded.tick(at: 3)
    reloaded.choose(reloaded.bubbles[1].id, at: 4)
    reloaded.continueToFeeling()
    reloaded.feeling = 0.1
    reloaded.reviewPick()
    reloaded.keepOriginalPick()
    precondition(!reloaded.needsAlternativeFeeling)
    reloaded.saveDecision()
    precondition(reloaded.savedDecisions.count == 1 && reloaded.lastSaved?.id == savedID
      && reloaded.lastSaved?.feeling == 0.1)
    try reloaded.deleteDecision(savedID)
    precondition(TurboSession(storageURL: file).savedDecisions.isEmpty)
    reloaded.prepareNew()
    precondition(reloaded.filledOptions.isEmpty)

    precondition(model.start() && model.chosen == nil && model.lastSaved == nil && model.reserves == [1, 1, 1])
    model.tick(at: 0)
    model.pause(at: 1)
    model.resume(at: 5)
    precondition(model.phase == .countdown && model.countdownNumber == 3 && model.elapsed == 0)
    model.tick(at: 8)
    model.rescue(first, at: 8)
    for time in 10...14 { model.rescue(first, at: Double(time)) }
    model.tick(at: 17)
    precondition(model.phase == .picked && model.chosen?.id == first && model.activeBubbles.count == 1,
      "Refilling a favorite must let it outlast untouched bubbles")

    precondition(model.start())
    model.tick(at: 0)
    model.tick(at: 3)
    model.rescue(first, at: 3)
    model.discard(first, at: 4)
    model.tick(at: 15)
    precondition(model.phase == .timedOut && model.chosen == nil,
      "An explicitly discarded option can never reappear as a result")
    precondition(model.start())
    model.tick(at: 0)
    model.tick(at: 15)
    precondition(model.phase == .timedOut && model.chosen == nil,
      "An unattended round must start and end on its own")
    for count in 3...6 {
      model.options = (0..<count).map { TurboOption(text: "Option \($0)") }
      precondition(model.start() && model.duration == Double(3 + 2 * count))
    }
    precondition(model.addOption() == nil)
    model.options.append(TurboOption(text: "Seven"))
    precondition(!model.start())

    // A delayed update must produce the same drain as several smaller updates.
    let dense = TurboSession(storageURL: file)
    let sparse = TurboSession(storageURL: file)
    dense.options = (1...3).map { TurboOption(text: "Pick \($0)") }
    sparse.options = dense.options
    var denseRandom = TestRandom()
    var sparseRandom = TestRandom()
    precondition(dense.start(using: &denseRandom) && sparse.start(using: &sparseRandom))
    dense.tick(at: 0)
    sparse.tick(at: 0)
    for second in 1...8 { dense.tick(at: Double(second)) }
    sparse.tick(at: 8)
    precondition(dense.reserves == sparse.reserves)
    dense.tick(at: 9)
    dense.tick(at: 10)
    sparse.tick(at: 10)
    precondition(dense.phase == .timedOut && dense.phase == sparse.phase && dense.elapsed == sparse.elapsed)

    let blocked = folder.appending(path: "not-a-folder")
    try Data().write(to: blocked)
    let failure = TurboSession(storageURL: blocked.appending(path: "record.json"))
    failure.options = dense.options
    precondition(failure.start())
    failure.tick(at: 0)
    failure.tick(at: 3)
    failure.choose(failure.bubbles[0].id, at: 4)
    failure.continueToFeeling()
    failure.saveDecision()
    precondition(failure.phase == .feeling && failure.lastSaved == nil && failure.saveError != nil)
    checkBubbleMotion()
    print("Turbo checks passed: Start countdown, automatic play, proportional duration, fast refills, burst outcome, pause/resume, replay and persistence")
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
              precondition(distance >= outerDiameter - 1e-8, "Progress rings must never overlap")
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
