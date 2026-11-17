import AVFoundation
import Foundation

@main struct AudioWaveformChecks {
  static func measure(amplitude: Double, channels: Int = 1, interleaved: Bool = false) -> [Double] {
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
        channels: AVAudioChannelCount(channels), interleaved: interleaved),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480),
      let data = buffer.floatChannelData
    else { preconditionFailure("Could not allocate fixture") }
    let meter = MicrophoneLevelMeter()
    buffer.frameLength = 480
    var levels: [Double] = []
    for block in 0..<100 {
      for channel in 0..<channels {
        for frame in 0..<480 {
          let t = Double(block * 480 + frame) / 48_000
          data[channel][frame * buffer.stride] = Float(amplitude * sin(2 * .pi * 440 * t))
        }
      }
      if let value = meter.consume(buffer) { levels.append(value) }
    }
    return levels
  }

  @MainActor static func main() {
    let silence = measure(amplitude: 0)
    precondition(
      silence.count == 20 && silence.allSatisfy { $0 == 0 }, "Silence must not invent audio peaks")
    let quiet = measure(amplitude: 0.002)
    let loud = measure(amplitude: 0.04)
    let expected = (20 * log10(0.04 / sqrt(2)) + 65) / 40
    precondition(loud.count == 20 && quiet.count == 20, "Publish at 20 Hz, not at the buffer rate")
    precondition(
      zip(quiet, loud).allSatisfy { $0 < $1 }, "Bar height must track microphone amplitude")
    precondition(
      loud.allSatisfy { abs($0 - expected) < 0.001 }, "Sine-wave RMS must match its known energy")
    let stereo = measure(amplitude: 0.04, channels: 2, interleaved: true)
    precondition(
      zip(loud, stereo).allSatisfy { abs($0 - $1) < 0.001 },
      "Interleaved stereo must not double the level")
    precondition(AudioLevelAccumulator.normalizedLevel(rms: 10) == 1)
    precondition(AudioLevelAccumulator.normalizedLevel(rms: .nan) == 0)
    let history = WaveformHistory()
    for index in 0..<200 { history.append(level: Double(index) / 200) }
    precondition(history.samples.count == 80 && Set(history.samples.map(\.id)).count == 80)
    precondition(history.samples.first?.id == 120 && history.samples.last?.id == 199)
    history.reset()
    precondition(history.samples.isEmpty, "A new dictation must not show the previous recording")
    print(
      "PASS: PCM silence, amplitude response, known sine RMS, 20Hz updates, stereo, bounds, rolling history and reset"
    )
  }
}
