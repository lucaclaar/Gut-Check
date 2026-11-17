import Foundation

enum SafetyConcern: String, Identifiable, Sendable {
  case selfHarm, violence, medical, support

  var id: String { rawValue }

  var message: String {
    switch self {
    case .selfHarm, .support:
      "Non devi affrontare questo momento da solo. Puoi chiedere aiuto a una persona."
    case .violence:
      "Se tu o un’altra persona siete in pericolo, contatta subito i soccorsi."
    case .medical:
      "Se pensi che sia un’emergenza medica, contatta subito i soccorsi."
    }
  }
}
