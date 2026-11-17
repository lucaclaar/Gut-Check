import Foundation

nonisolated enum SpeechCaptureError: LocalizedError {
  case activationFailed, noMicrophone

  var errorDescription: String? {
    switch self {
    case .activationFailed: "Couldn't start the microphone. You can type your question instead."
    case .noMicrophone: "No microphone is available. You can type your question instead."
    }
  }
}
