import Foundation

enum ReflectionDeviceQuestions {
  static func make(about focus: String, lens: ReflectionLens) -> [String]? {
    var phrase = focus.trimmingCharacters(in: .whitespacesAndNewlines)
    if phrase.last == "?" { phrase.removeLast() }
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
    let action = phrase.prefix(1).lowercased() + phrase.dropFirst()

    let positive = [
      "Would you look back in ten years and be glad you chose to \(action)?",
      "Would your older self see a good reason to \(action)?",
      "Could choosing to \(action) bring you closer to the life you want?",
      "Could this choice open up an opportunity you’d want to pursue?",
      "Would you look forward to what a decision to \(action) might make possible?",
      "Would you be glad you made time for this if it worked out?",
    ]
    let downside = [
      "If you chose to \(action) and it went badly, could you manage the consequences?",
      "Would it feel worthwhile to \(action) even if things didn’t work out?",
      "Could you handle needing more time than expected to \(action)?",
      "If you needed to change course, would you have a way back?",
      "Would you have support if it got harder to \(action)?",
      "If this plan fell through, could you take another path?",
    ]
    switch lens {
    case .best: return positive
    case .worst: return downside
    case .mixed:
      return [
        "Would you still want to \(action) if nobody knew about your choice?",
        "Could you see a good reason for a friend to \(action)?",
      ] + positive.prefix(2) + downside.prefix(2)
    }
  }
}
