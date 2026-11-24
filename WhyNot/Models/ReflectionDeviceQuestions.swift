import Foundation

enum ReflectionDeviceQuestions {
  static func hasVerbatimEvidence(_ quote: String, in dilemma: String) -> Bool {
    let evidence = quote.trimmingCharacters(in: .whitespacesAndNewlines)
    return evidence.split(whereSeparator: \.isWhitespace).count >= 2
      && dilemma.range(of: evidence, options: .literal) != nil
  }

  static func make(about focus: String, lens: ReflectionLens) -> [String]? {
    var phrase = focus.trimmingCharacters(in: .whitespacesAndNewlines)
    if let last = phrase.last, ".?".contains(last) { phrase.removeLast() }
    let prefixes = ["should i ", "should we ", "whether i should ", "whether to ", "to "]
    if let prefix = prefixes.first(where: { phrase.lowercased().hasPrefix($0) }) {
      phrase.removeFirst(prefix.count)
    }
    let statusQuo = [" or stay here", " or stay put", " or stay where i am", " or keep things as they are"]
    if let suffix = statusQuo.first(where: { phrase.lowercased().hasSuffix($0) }) {
      phrase.removeLast(suffix.count)
    }
    phrase = phrase.split(separator: " ").joined(separator: " ")
    guard (2...12).contains(phrase.split(separator: " ").count), phrase.count <= 70,
      phrase.range(of: #"^[\p{L}\p{M}\p{N} ’'&-]+$"#, options: .regularExpression) != nil
    else { return nil }
    let action = (phrase.prefix(1).lowercased() + phrase.dropFirst())
      .replacing(#/^study (a (?:master['’]s|bachelor['’]s) degree)\b/#) { "pursue \($0.1)" }

    let positive = [
      "Would you look back in ten years and be glad you decided to \(action)?",
      "Would it make your everyday life better to \(action)?",
      "If you decided to \(action), would you have more room for something you care about?",
      "Could this choice open up an opportunity worth exploring?",
      "Would you enjoy what you might learn if you went ahead?",
      "Would you rather leave things as they are than \(action)?",
    ]
    let downside = [
      "If you decided to \(action) and it went badly, could you manage the consequences?",
      "Would it feel worthwhile to \(action) if you had to give something up?",
      "Could you handle needing more time than expected to \(action)?",
      "If you needed to change course, would you have a way back?",
      "Would you have support if it got harder to \(action)?",
      "Would you rather leave things as they are than take that risk?",
    ]
    switch lens {
    case .best: return positive
    case .worst: return downside
    case .mixed:
      return [
        "Would you still want to \(action) if nobody knew about your choice?",
        "Would you rather leave things as they are than \(action)?",
      ] + positive.prefix(2) + downside.prefix(2)
    }
  }
}
