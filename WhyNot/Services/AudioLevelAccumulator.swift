import Foundation

/// Produces one amplitude measurement per 50 ms of audio, rather than one UI
/// update per audio buffer. Silence stays flat; speech/music follows its RMS.
nonisolated struct AudioLevelAccumulator: Sendable {
  private var sumOfSquares = 0.0
  private var sampleCount = 0
  private var duration = 0.0

  mutating func consume(sumOfSquares: Double, sampleCount: Int, duration: Double) -> Double? {
    guard sumOfSquares.isFinite, sumOfSquares >= 0, sampleCount > 0,
      duration.isFinite, duration > 0
    else { return nil }
    self.sumOfSquares += sumOfSquares
    self.sampleCount += sampleCount
    self.duration += duration
    guard self.duration >= 0.05 else { return nil }
    let rms = sqrt(self.sumOfSquares / Double(self.sampleCount))
    self.sumOfSquares = 0
    self.sampleCount = 0
    self.duration = 0
    return Self.normalizedLevel(rms: rms)
  }

  static func normalizedLevel(rms: Double) -> Double {
    guard rms.isFinite, rms > 0 else { return 0 }
    let decibels = 20 * log10(rms)
    // Display range tuned for a phone microphone: normal/soft speech must be
    // visible without requiring input levels close to digital full scale.
    return min(1, max(0, (decibels + 65) / 40))
  }
}
