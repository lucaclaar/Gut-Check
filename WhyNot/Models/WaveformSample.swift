import Foundation

nonisolated struct WaveformSample: Identifiable, Equatable, Sendable {
  let id: UInt64
  let level: Double
  let timestamp: Date
}
