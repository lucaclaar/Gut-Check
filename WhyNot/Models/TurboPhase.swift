enum TurboPhase: Equatable {
  case setup, countdown, playing, paused, picked, tie, timedOut, feeling, saved
}

/// Why the round ended with a pick.
enum TurboOutcome: String, Codable, Equatable {
  /// Every other option popped or was let go.
  case lastStanding
  /// The person held an option to pick it.
  case held
  /// Time ran out and this option had the most saves.
  case mostSaves
  /// Time ran out on a tie and the person picked between the tied options.
  case tieBreak
}
