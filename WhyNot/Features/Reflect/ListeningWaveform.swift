import SwiftUI

struct ListeningWaveform: View {
  let waveform: WaveformHistory
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let restingHeights: [Double] = [10, 18, 26, 14, 30, 22, 12, 24, 16, 8, 20, 28, 14, 10]

  var body: some View {
    // Reading here scopes audio updates to this view, not the entire screen.
    let samples = waveform.samples
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let pitch = 9.0
        let barWidth = 4.0
        let columns = Int(size.width / pitch) + 1
        var phase = 0.0
        if !reduceMotion, let latest = samples.last {
          let previous =
            samples.dropLast().last?.timestamp ?? latest.timestamp.addingTimeInterval(-0.05)
          let interval = min(0.15, max(0.03, latest.timestamp.timeIntervalSince(previous)))
          phase = min(1, max(0, timeline.date.timeIntervalSince(latest.timestamp) / interval))
        }
        // One shared scroll phase keeps spacing uniform. Never overlay a second
        // dotted baseline, and never let bars shrink into round points.
        for offset in 0...columns {
          let x = size.width - barWidth - (Double(offset) + phase) * pitch
          guard x >= -barWidth else { continue }
          let sampleIndex = samples.count - 1 - offset
          let height: Double
          if samples.isEmpty {
            height = restingHeights[(columns - offset) % restingHeights.count]
          } else if sampleIndex >= 0 {
            height = 8 + sqrt(samples[sampleIndex].level) * (size.height - 8)
          } else {
            height = 8
          }
          let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
          context.fill(
            Path(roundedRect: rect, cornerRadius: 2), with: .color(.white.opacity(0.85)))
        }
      }
    }
    .frame(width: 122, height: 34)
    .clipped()
    .accessibilityHidden(true)
  }
}
