import Foundation
import Observation

@MainActor @Observable
final class WaveformHistory {
  private(set) var samples: [WaveformSample] = []
  @ObservationIgnored private var nextID: UInt64 = 0

  func append(level: Double, at timestamp: Date = .now) {
    guard level.isFinite else { return }
    samples.append(WaveformSample(id: nextID, level: min(1, max(0, level)), timestamp: timestamp))
    nextID &+= 1
    if samples.count > 80 { samples.removeFirst(samples.count - 80) }
  }

  func reset() { samples = [] }
}
