import Foundation

/// Panic-mode timing. Every value scales from the round length so the round can
/// be tuned in one place; the defaults come from the v2 prototype tests (15 s).
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

  init(round: Double = 15) {
    func half(_ value: Double) -> Double { (value * 2).rounded() / 2 }
    self.round = round
    shortestTimer = round * 0.2
    longestTimer = round * 0.8
    tapBonus = max(0.5, half(round / 15))
    maximumTimer = round * 0.8
    lastSecondWindow = max(1.5, half(round * 0.13))
  }
}
