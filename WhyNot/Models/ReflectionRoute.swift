enum ReflectionRoute: String, Codable {
  case setup, cards, pause, walk, returnFromWalk, decision, saved, deferred
  case turboSetup, turboGame, turboResult, turboFeeling, turboSaved

  var isDraftStep: Bool {
    switch self {
    case .setup, .cards, .pause, .walk, .returnFromWalk, .decision: true
    default: false
    }
  }
}
