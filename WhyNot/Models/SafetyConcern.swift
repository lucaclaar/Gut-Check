import Foundation

enum SafetyConcern: String, Identifiable, Sendable {
  case selfHarm, violence, medical, support

  var id: String { rawValue }

  var message: String {
    switch self {
    case .selfHarm, .support:
      "You don’t have to face this alone. Help is a call away."
    case .violence:
      "If you or someone else is in immediate danger, call emergency services."
    case .medical:
      "If this could be a medical emergency, call emergency services."
    }
  }
}
