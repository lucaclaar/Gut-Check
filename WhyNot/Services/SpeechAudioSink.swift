import AVFoundation
import Foundation
import Speech

// Speech's legacy request is not Sendable. Serialise its audio writes and finish
// operation; configure it and create the recognition task before starting audio.
nonisolated final class SpeechAudioSink: @unchecked Sendable {
  let request: SFSpeechAudioBufferRecognitionRequest
  private let lock = NSLock()
  private var ended = false

  init(request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }
  func append(_ buffer: AVAudioPCMBuffer) {
    lock.withLock {
      if !ended { request.append(buffer) }
    }
  }

  func finish() {
    lock.withLock {
      guard !ended else { return }
      ended = true
      request.endAudio()
    }
  }
}
