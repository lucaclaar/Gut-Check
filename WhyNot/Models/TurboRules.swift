import Foundation

/// Panic-mode timing. Every value scales from the round length so the round can
/// be tuned in one place; the defaults come from the v2 prototype tests (15 s).
struct TurboRules: Equatable {
  let round: Double
  /// Hidden per-option timers are spread between these two values.
  let shortestTimer: Double
  let longestTimer: Double
  /// Time added by the first, second and third save. A fourth save is refused.
  let saveBonuses: [Double]
  /// No option can hold more time than this, however often it is saved.
  let maximumTimer: Double
  /// A save with this much time left or less counts as a last-second save.
  let lastSecondWindow: Double

  init(round: Double = 15) {
    func half(_ value: Double) -> Double { (value * 2).rounded() / 2 }
    self.round = round
    shortestTimer = round * 0.2
    longestTimer = round * 0.8
    saveBonuses = [half(round * 0.2), half(round * 0.13), half(round * 0.07)]
    maximumTimer = round * 0.5
    lastSecondWindow = max(1.5, half(round * 0.13))
  }

  var savesPerOption: Int { saveBonuses.count }
}
