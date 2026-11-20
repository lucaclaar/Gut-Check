import Foundation

struct ReflectionQuestion: Identifiable, Codable, Equatable {
  let id: Int
  let lens: ReflectionLens
  let eyebrow: String
  let text: String
  let mascot: String

  /// Shown once before the first real card. Its answer is never stored.
  static func practice(for lens: ReflectionLens) -> Self {
    Self(id: 0, lens: lens, eyebrow: "PRACTICE CARD", text: "Swipe right for Yes, left for No.",
      mascot: lens.mascot)
  }

  static let all: [Self] = [
    .init(
      id: 1, lens: .best, eyebrow: "IN 10 YEARS", text: "Will you be glad you did it?",
      mascot: "MascotBestCase1"),
    .init(
      id: 2, lens: .best, eyebrow: "80-YEAR-OLD YOU", text: "Would they tell you to go for it?",
      mascot: "MascotBestCase2"),
    .init(
      id: 3, lens: .mixed, eyebrow: "IF NO ONE WAS WATCHING", text: "Would you still choose it?",
      mascot: "MascotMixedEmotions3"),
    .init(
      id: 4, lens: .mixed, eyebrow: "YOUR BEST FRIEND",
      text: "If they were in your shoes, would you tell them to do it?",
      mascot: "MascotMixedEmotions1"),
    .init(
      id: 5, lens: .worst, eyebrow: "IF IT GOES WRONG", text: "Could you live with it?",
      mascot: "MascotWorstCase1"),
    .init(
      id: 6, lens: .worst, eyebrow: "IF IT FAILS", text: "Would you still want the experience?",
      mascot: "MascotWorstCase3"),
    .init(id: 7, lens: .best, eyebrow: "IF IT GOES WELL",
      text: "Would this bring you closer to the life you want?", mascot: "MascotBestCase1"),
    .init(id: 8, lens: .best, eyebrow: "A DOOR OPENS",
      text: "Would the opportunities it creates make the leap worthwhile?", mascot: "MascotBestCase2"),
    .init(id: 9, lens: .best, eyebrow: "A GOOD SURPRISE",
      text: "Would you be excited to see where this takes you?", mascot: "MascotBestCase1"),
    .init(id: 10, lens: .best, eyebrow: "FUTURE YOU",
      text: "If this worked out, would you wish you’d started sooner?", mascot: "MascotBestCase2"),
    .init(id: 11, lens: .worst, eyebrow: "A SETBACK",
      text: "If this cost more time than expected, could you manage it?", mascot: "MascotWorstCase1"),
    .init(id: 12, lens: .worst, eyebrow: "CHANGE OF PLANS",
      text: "If you needed to back out, would you have a way to do it?", mascot: "MascotWorstCase3"),
    .init(id: 13, lens: .worst, eyebrow: "THE HARD PART",
      text: "If this got harder than you expected, would you have support?", mascot: "MascotWorstCase4"),
    .init(id: 14, lens: .worst, eyebrow: "STARTING OVER",
      text: "If this fell through, could you take another path?", mascot: "MascotWorstCase1"),
  ]

  static func deck(for lens: ReflectionLens) -> [Self] {
    if lens == .mixed {
      return all.filter { $0.lens == .mixed }
        + all.filter { $0.lens != .mixed && (1...6).contains($0.id) }
    }
    return all.filter { $0.lens == lens }
  }

  static func personalized(_ questions: [String], for lens: ReflectionLens) -> [Self]? {
    let templates = deck(for: lens)
    guard questions.count == templates.count else { return nil }

    let texts = questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    let keys = texts.map {
      $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
        .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        .joined(separator: " ")
    }
    guard Set(keys).count == templates.count, texts.allSatisfy(isYesNoQuestion)
    else { return nil }

    return zip(templates, texts).map { template, text in
      Self(id: template.id + 100, lens: template.lens, eyebrow: template.eyebrow,
        text: text, mascot: template.mascot)
    }
  }

  private static func isYesNoQuestion(_ text: String) -> Bool {
    guard text.count <= 145, !text.contains(where: \.isNewline),
      text.last == "?", text.count(where: { $0 == "?" }) == 1,
      text.split(whereSeparator: \.isWhitespace).count >= 4,
      text.range(of: #"(?i)https?://|www\.|tel:|\b(?:call|dial|text)\s+\+?\d"#,
        options: .regularExpression) == nil
    else { return false }

    let opening = text.lowercased()
    let question = opening.hasPrefix("if ") ? opening.split(separator: ",", maxSplits: 1).last : opening[...]
    guard let auxiliary = question?.split(whereSeparator: \.isWhitespace).first else { return false }
    return ["am", "are", "can", "could", "did", "do", "does", "had", "has", "have", "is",
      "might", "should", "was", "were", "will", "would"].contains(String(auxiliary))
  }
}
