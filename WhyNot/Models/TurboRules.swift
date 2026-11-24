import Foundation

/// Panic-mode timing. The round stays on a wall clock while option timers drain faster near the end.
struct TurboRules: Equatable {
  let round: Double
  /// Hidden per-option timers are spread between these two values.
  let shortestTimer: Double
  let longestTimer: Double
  /// Time each tap adds to an option. Taps are unlimited; the round never gets longer.
  let tapBonus: Double
  /// A full bubble. Taps top an option up to this, never past it.
  let maximumTimer: Double
  /// A tap with this much time left or less counts as a last-second save.
  let lastSecondWindow: Double
  private var accelerationStart: Double { round * 0.6 }
  private var acceleration: Double { 0.65 / (round - accelerationStart) }

  init(optionCount: Int) {
    self.init(round: 9 + Double(min(6, max(3, optionCount)) - 3))
  }

  init(round: Double = 15) {
    func half(_ value: Double) -> Double { (value * 2).rounded() / 2 }
    self.round = round
    shortestTimer = round * 0.2
    longestTimer = round * 0.8
    tapBonus = max(0.5, half(round / 15))
    maximumTimer = round * 0.8
    lastSecondWindow = max(1.5, half(round * 0.13))
  }

  func urgency(at time: Double) -> Double {
    min(1, max(0, (time - accelerationStart) / (round - accelerationStart)))
  }

  func depletion(at time: Double) -> Double {
    let acceleratedTime = max(0, time - accelerationStart)
    return time + acceleration * acceleratedTime * acceleratedTime / 2
  }

  /// Invert the drain curve so expiries still land on the correct wall-clock instant.
  func time(forDepletion depletion: Double) -> Double {
    guard depletion > accelerationStart else { return depletion }
    let excess = depletion - accelerationStart
    return accelerationStart + 2 * excess / (1 + sqrt(1 + 2 * acceleration * excess))
  }
}
