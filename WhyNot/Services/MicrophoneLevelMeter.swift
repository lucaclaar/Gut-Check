import AVFoundation
import Synchronization

/// The tap supplies Float32 PCM. State is protected across callback invocations;
/// buffers and channel pointers never escape this synchronous method.
nonisolated final class MicrophoneLevelMeter: Sendable {
  private let accumulator = Mutex(AudioLevelAccumulator())

  func consume(_ buffer: AVAudioPCMBuffer) -> Double? {
    let frames = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)
    let sampleRate = buffer.format.sampleRate
    guard frames > 0, channels > 0, sampleRate.isFinite, sampleRate > 0,
      let data = buffer.floatChannelData
    else { return nil }
    var sum = 0.0
    for channel in 0..<channels {
      for frame in 0..<frames {
        let sample = Double(data[channel][frame * buffer.stride])
        if sample.isFinite { sum += sample * sample }
      }
    }
    return accumulator.withLock {
      $0.consume(
        sumOfSquares: sum, sampleCount: frames * channels,
        duration: Double(frames) / sampleRate)
    }
  }
}
