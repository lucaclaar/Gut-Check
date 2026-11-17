import AVFoundation
import Foundation

/// Audio I/O stays off MainActor. SpeechInput serialises start/stop commands,
/// including their asynchronous activation/deactivation completions.
actor SpeechCapture {
  private var engine: AVAudioEngine?
  private var hasTap = false
  private var sessionActive = false

  func start(sink: SpeechAudioSink, onLevel: @escaping @Sendable (Double) -> Void) async throws {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .measurement)
      guard try await session.activate(options: []) else {
        throw SpeechCaptureError.activationFailed
      }
      sessionActive = true

      let engine = AVAudioEngine()
      self.engine = engine
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate.isFinite, format.sampleRate > 0, format.channelCount > 0 else {
        throw SpeechCaptureError.noMicrophone
      }
      let meter = MicrophoneLevelMeter()
      try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        let audio = AVAudioPCMBuffer(copying: buffer)
        sink.append(audio)
        if let level = meter.consume(audio) { onLevel(level) }
      }
      hasTap = true
      engine.prepare()
      try engine.start()
    } catch {
      await stop()
      throw error
    }
  }

  func stop() async {
    if let engine {
      engine.stop()
      if hasTap { engine.inputNode.removeTap(onBus: 0) }
    }
    engine = nil
    hasTap = false
    // Leaving Reflect without ever dictating must not touch the audio session.
    guard sessionActive else { return }
    sessionActive = false
    _ = try? await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation)
  }
}
