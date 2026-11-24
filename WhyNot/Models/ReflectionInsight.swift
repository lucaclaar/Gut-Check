import Foundation

struct ReflectionInsight: Equatable {
  enum Leaning: String, Equatable {
    case toward, away, mixed

    var title: String {
      switch self {
      case .toward: "You seem drawn to it."
      case .away: "You seem to be leaning away."
      case .mixed: "You might need more time."
      }
    }

    var mascot: String {
      switch self {
      case .toward: "MascotBestCase1"
      case .away: "MascotStillDoubtful1"
      case .mixed: "MascotMixedEmotions1"
      }
    }
  }

  private enum Signal: Int {
    case preference = 3
    case benefit = 1
    case objection = -3
    case practical = 0
  }

  let leaning: Leaning
  let summary: String
  let evidence: [ReflectionAnswer]

  static func offline(from answers: [ReflectionAnswer]) -> Self {
    let signals = answers.compactMap { answer -> (ReflectionAnswer, Signal, Int)? in
      guard let signal = signal(in: answer.question) else { return nil }
      return (answer, signal, answer.yes ? signal.rawValue : -signal.rawValue)
    }
    let score = signals.reduce(0) { $0 + $1.2 }
    let direct = signals.filter { abs($0.2) == 3 }
    let conflicting = direct.contains { $0.2 > 0 } && direct.contains { $0.2 < 0 }
    let requiredMargin = conflicting ? 4 : 3
    let leaning: Leaning
    if score >= requiredMargin && signals.count(where: { $0.2 > 0 }) >= 2
      && (direct.isEmpty || direct.contains { $0.2 > 0 })
    {
      leaning = .toward
    } else if score <= -requiredMargin && signals.count(where: { $0.2 < 0 }) >= 2
      && (direct.isEmpty || direct.contains { $0.2 < 0 })
    {
      leaning = .away
    } else {
      leaning = .mixed
    }

    let ranked = signals.sorted { abs($0.2) > abs($1.2) }
    let main = ranked.first {
      $0.2 != 0 && (leaning == .mixed || ($0.2 > 0) == (leaning == .toward))
    }
    let contrast = ranked.first { item in
      guard let main else { return false }
      return item.0.id != main.0.id && ((item.2 == 0 ? !item.0.yes : (item.2 > 0) != (main.2 > 0)))
    }
    let evidenced = [main?.0, contrast?.0].compactMap { $0 }
    let evidence = evidenced.isEmpty ? Array(answers.suffix(2)) : evidenced
    let summary: String
    switch leaning {
    case .toward:
      summary =
        contrast == nil
        ? "Your answers suggest this choice has something you want."
        : "You see something worth doing here, even though some of the trade-offs still need a closer look."
    case .away:
      summary =
        "Your answers suggest you’d hesitate to choose this, even after considering what could go well."
    case .mixed:
      summary =
        answers.isEmpty
        ? "Try a few cards to see what matters most to you."
        : "Your answers leave room for more than one choice. Give the part you’re least sure about some attention."
    }
    return Self(leaning: leaning, summary: summary, evidence: evidence)
  }

  static func grounded(
    leaning: Leaning, summary: String, dilemma: String,
    evidence: [ReflectionAnswer]
  ) -> Self {
    let source = ([dilemma] + evidence.map { $0.question.text }).joined(separator: " ")
    let summaryWords = contentWords(in: summary)
    let supported = !summaryWords.isEmpty && summaryWords.isSubset(of: contentWords(in: source))
    let fallback =
      switch leaning {
      case .toward: "These answers point to something about this option that appeals to you."
      case .away: "These answers give you a reason to reconsider this option."
      case .mixed:
        "These answers leave the choice open. Give yourself time to weigh what matters most."
      }
    return Self(leaning: leaning, summary: supported ? summary : fallback, evidence: evidence)
  }

  private static func contentWords(in text: String) -> Set<String> {
    let common: Set<String> = [
      "about", "after", "also", "answer", "answers", "based", "because", "been", "could", "from",
      "have", "here", "into", "itself", "look", "looks", "make", "might", "more", "only", "part",
      "seem", "seems", "some", "still", "than", "that", "their", "them", "then", "these", "they",
      "think", "this", "those", "toward", "very", "want", "what", "when", "where", "whether",
      "which", "while", "will", "with", "would", "your",
    ]
    let folded = text.folding(
      options: [.caseInsensitive, .diacriticInsensitive],
      locale: Locale(identifier: "en"))
    return Set(
      folded.split { !$0.isLetter && !$0.isNumber }.compactMap { word in
        guard !common.contains(String(word)),
          word.count > 3 || word.contains(where: \.isNumber)
        else { return nil }
        if word.count > 6, word.hasSuffix("ing") { return String(word.dropLast(3)) }
        if word.count > 5, word.hasSuffix("ed") { return String(word.dropLast(2)) }
        if word.count > 4, word.hasSuffix("s") { return String(word.dropLast()) }
        return String(word)
      })
  }

  private static func signal(in question: ReflectionQuestion) -> Signal? {
    // Classify the main clause so an outcome in an If clause never becomes the user's answer.
    let text = question.text.lowercased()
    let clause =
      text.hasPrefix("if ") ? String(text.split(separator: ",", maxSplits: 1).last ?? "") : text
    if clause.contains("rather not") || clause.contains("rather skip")
      || clause.contains("rather stay home") || clause.contains("rather leave things as they are")
      || clause.contains("regret going")
      || clause.contains("regret doing")
    {
      return .objection
    }
    if ReflectionQuestion.all.contains(where: { $0.id == question.id && $0.lens == question.lens }) {
      switch question.id {
      case 1, 3, 6, 9: return .preference
      case 2, 4, 7, 8, 10: return .benefit
      default: return .practical
      }
    }
    if [
      "manage the consequences", "could you manage", "could you handle", "would you have support",
      "way back", "take another path", "could you afford",
    ].contains(where: clause.contains) {
      return .practical
    }
    if [
      "glad you chose", "glad you decided", "would you still want", "would you enjoy",
      "would you look forward", "would it feel worthwhile", "would you still choose",
    ].contains(where: clause.contains) {
      return .preference
    }
    if [
      "good reason", "closer to the life", "open up an opportunity", "make your everyday life better",
      "more room for something you care about",
      "would you be glad",
    ].contains(where: clause.contains) {
      return .benefit
    }
    return nil
  }
}
