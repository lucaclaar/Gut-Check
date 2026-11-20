import AVFoundation
import Observation
import Speech

@MainActor @Observable
final class SpeechInput {
  private(set) var isListening = false
  private(set) var isPreparing = false
  private(set) var transcript = ""
  let waveform = WaveformHistory()
  var showError = false
  private(set) var errorMessage = ""
  @ObservationIgnored private let capture = SpeechCapture()
  @ObservationIgnored private var audioOperation: Task<Void, Never>?
  @ObservationIgnored private var sink: SpeechAudioSink?
  @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
  @ObservationIgnored private var finalization: Task<Void, Never>?
  @ObservationIgnored private var generation = 0
  func start() async {
    guard !isListening, !isPreparing else { return }
    stop()
    let operation = generation
    isPreparing = true
    let authorized = await Self.requestSpeechPermission()
    guard generation == operation, !Task.isCancelled else { return }
    guard authorized else {
      fail("Allow Microphone and Speech Recognition in Settings to use dictation.")
      return
    }
    let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
    guard generation == operation, !Task.isCancelled else { return }
    guard microphoneAllowed else {
      fail("Allow Microphone in Settings to use dictation.")
      return
    }
    guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
      fail("Speech recognition is currently unavailable. You can type instead.")
      return
    }
    transcript = ""
    waveform.reset()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    let sink = SpeechAudioSink(request: request)
    self.sink = sink
    recognitionTask = recognizer.recognitionTask(with: request) {
      @Sendable [weak self] result, error in
      let text = result?.bestTranscription.formattedString
      let finished = result?.isFinal ?? false
      let message = error?.localizedDescription
      Task { @MainActor [weak self] in
        guard let self, self.generation == operation else { return }
        if let text { self.transcript = text }
        if finished {
          self.stop()
        } else if let message {
          if self.finalization != nil && !self.transcript.isEmpty { self.stop() }
          else { self.fail(message) }
        }
      }
    }
    let previous = audioOperation
    let capture = capture
    let task = Task { [weak self] in
      await previous?.value
      guard let self, self.generation == operation else { return }
      do {
        try await capture.start(sink: sink) { @Sendable [weak self] level in
          Task { @MainActor [weak self] in
            guard let self, self.generation == operation else { return }
            self.waveform.append(level: level)
          }
        }
        guard self.generation == operation else { return }
        self.isPreparing = false
        self.isListening = true
      } catch {
        guard self.generation == operation else { return }
        self.fail(error.localizedDescription)
      }
    }
    audioOperation = task
    await task.value
  }
  func finish() {
    guard isListening else { return }
    isListening = false
    isPreparing = true
    let operation = generation
    finalization = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
      guard let self, self.generation == operation else { return }
      self.stop()
    }
    stopAudio()
  }

  func stop() {
    finalization?.cancel()
    finalization = nil
    generation += 1
    isListening = false
    isPreparing = false
    waveform.reset()
    recognitionTask?.cancel()
    recognitionTask = nil
    stopAudio()
  }

  private func stopAudio() {
    guard let sink else { return }
    sink.finish()
    self.sink = nil
    let previous = audioOperation
    let capture = capture
    audioOperation = Task {
      await previous?.value
      await capture.stop()
    }
  }
  // Speech invokes this legacy completion on a system queue. Explicitly
  // Sendable/nonisolated prevents Swift 6 from inserting a MainActor assertion.
  nonisolated private static func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { @Sendable status in
        continuation.resume(returning: status == .authorized)
      }
    }
  }
  private func fail(_ message: String) {
    stop()
    errorMessage = message
    showError = true
  }
}
