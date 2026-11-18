import Foundation

enum TurboChecks {
  static func run() throws {
    let folder = URL.temporaryDirectory.appending(path: "turbo-checks-\(UUID())")
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appending(path: "turbo-decisions.json")
    let model = TurboSession(storageURL: file)
    model.options = [TurboOption(text: "One"), TurboOption(text: "Two")]
    precondition(!model.start(), "At least three options are required")
    model.options.append(TurboOption(text: " one "))
    precondition(!model.start(), "Names must be distinct after trimming/case folding")
    model.options[2].text = "Three"
    let blank = model.addOption()!
    precondition(model.addOption() == blank && model.plannedSeconds == 16,
      "A blank field must not inflate the timer")
    model.removeOption(blank)
    model.options[0].text = "I want to kill myself"
    precondition(!model.start(), "Unsafe options must never enter the game")
    model.options[0].text = "One"

    precondition(model.start() && model.phase == .countdown
      && model.countdownNumber == 3 && model.remaining == 16)
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
    precondition(model.phase == .playing && model.remaining == 16 && model.reserves == [1, 1, 1])
    model.rescue(first, at: 103)
    model.tick(at: 107)
    let drained = model.reserves[0]
    model.rescue(first, at: 107)
    model.rescue(first, at: 107.1)
    precondition(model.reserves[0] > drained + 0.18 && model.bubbles[0].rescues == 3,
      "Fast taps must refill the same bubble independently")
    precondition(model.reserves[1] < drained, "Refilling one bubble must not refill its neighbors")

    model.pause(at: 108)
    let pausedReserves = model.reserves
    model.tick(at: 1000)
    precondition(model.phase == .paused && model.elapsed == 5 && model.reserves == pausedReserves)
    model.resume(at: 1010)
    model.tick(at: 1012)
    precondition(model.phase == .countdown && model.countdownNumber == 1 && model.reserves == pausedReserves)
    model.tick(at: 1014)
    precondition(model.phase == .playing && model.elapsed == 6,
      "Countdown and background time must not drain the reserves")
    model.choose(second, at: 1014)
    precondition(model.phase == .picked && model.chosen?.text == "Two")
    model.continueToFeeling()
    model.returnToResult()
    precondition(model.phase == .picked)
    model.continueToFeeling()
    model.feeling = 0.8
    model.saveDecision()
    model.saveDecision()
    precondition(model.phase == .saved && model.savedDecisions.count == 1 && model.saveError == nil)
    let reloaded = TurboSession(storageURL: file)
    precondition(reloaded.savedDecisions.first?.choice == "Two"
      && reloaded.savedDecisions.first?.options.first?.rescues == 3)

    precondition(model.start() && model.chosen == nil && model.lastSaved == nil && model.reserves == [1, 1, 1])
    model.tick(at: 0)
    model.pause(at: 1)
    model.resume(at: 5)
    precondition(model.phase == .countdown && model.countdownNumber == 3 && model.elapsed == 0)
    model.tick(at: 8)
    model.rescue(first, at: 8)
    model.rescue(first, at: 12)
    model.rescue(first, at: 13)
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
      precondition(model.start() && model.duration == Double(4 + 4 * count))
    }
    precondition(model.addOption() == nil)
    model.options.append(TurboOption(text: "Seven"))
    precondition(!model.start())

    // A delayed update must produce the same drain as several smaller updates.
    let dense = TurboSession(storageURL: file)
    let sparse = TurboSession(storageURL: file)
    precondition(dense.start() && sparse.start())
    dense.tick(at: 0)
    sparse.tick(at: 0)
    for second in 1...8 { dense.tick(at: Double(second)) }
    sparse.tick(at: 8)
    precondition(abs(dense.reserves[0] - sparse.reserves[0]) < 1e-10)

    let blocked = folder.appending(path: "not-a-folder")
    try Data().write(to: blocked)
    let failure = TurboSession(storageURL: blocked.appending(path: "record.json"))
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
