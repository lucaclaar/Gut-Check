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
      id: 2, lens: .best, eyebrow: "EVERYDAY LIFE", text: "Would this make your everyday life better?",
      mascot: "MascotBestCase2"),
    .init(
      id: 3, lens: .mixed, eyebrow: "IF NO ONE WAS WATCHING", text: "Would you still choose it?",
      mascot: "MascotMixedEmotions3"),
    .init(
      id: 4, lens: .mixed, eyebrow: "THE OTHER OPTION",
      text: "Would you rather leave things as they are?",
      mascot: "MascotMixedEmotions1"),
    .init(
      id: 5, lens: .worst, eyebrow: "IF IT GOES WRONG", text: "Could you live with it?",
      mascot: "MascotWorstCase1"),
    .init(
      id: 6, lens: .worst, eyebrow: "WHAT YOU’D GIVE UP",
      text: "Would it still feel worthwhile if you had to give something up?",
      mascot: "MascotWorstCase3"),
    .init(id: 7, lens: .best, eyebrow: "YOUR PRIORITIES",
      text: "Would this make more room for something you care about?", mascot: "MascotBestCase1"),
    .init(id: 8, lens: .best, eyebrow: "A DOOR OPENS",
      text: "Would the opportunities it creates make the leap worthwhile?", mascot: "MascotBestCase2"),
    .init(id: 9, lens: .best, eyebrow: "WHAT YOU COULD LEARN",
      text: "Would you enjoy what you might learn along the way?", mascot: "MascotBestCase1"),
    .init(id: 10, lens: .best, eyebrow: "THE OTHER OPTION",
      text: "Would you rather leave things as they are?", mascot: "MascotBestCase2"),
    .init(id: 11, lens: .worst, eyebrow: "A SETBACK",
      text: "If this cost more time than expected, could you manage it?", mascot: "MascotWorstCase1"),
    .init(id: 12, lens: .worst, eyebrow: "CHANGE OF PLANS",
      text: "If you needed to back out, would you have a way to do it?", mascot: "MascotWorstCase3"),
    .init(id: 13, lens: .worst, eyebrow: "THE HARD PART",
      text: "If this got harder than you expected, would you have support?", mascot: "MascotWorstCase4"),
    .init(id: 14, lens: .worst, eyebrow: "THE OTHER OPTION",
      text: "Would you rather leave things as they are than take that risk?", mascot: "MascotWorstCase1"),
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

    let texts = questions.map(addressingUser)
    guard Set(texts.map(comparisonKey)).count == templates.count, texts.allSatisfy(isYesNoQuestion)
    else { return nil }

    return zip(templates, texts).map { template, text in
      Self(id: template.id + 100, lens: template.lens, eyebrow: template.eyebrow,
        text: text, mascot: template.mascot)
    }
  }

  static func isRestorableInitialDeck(_ cards: [Self], for lens: ReflectionLens) -> Bool {
    let templates = deck(for: lens)
    guard cards.count == templates.count, let first = cards.first else { return false }
    let idOffset = first.id >= 100 ? 100 : 0
    // Keep the text and headings from drafts opened before the card copy was updated.
    return zip(cards, templates).allSatisfy { card, template in
      card.id == template.id + idOffset && card.lens == template.lens
        && card.mascot == template.mascot && isYesNoQuestion(card.text)
    } && Set(cards.map { comparisonKey($0.text) }).count == cards.count
  }

  private static let readerPronouns = [
    "i": "you", "i am": "you are", "i was": "you were", "i wasn't": "you weren’t",
    "am i": "are you", "was i": "were you", "me": "you", "my": "your", "myself": "yourself",
    "we": "you", "us": "you", "our": "your", "ours": "yours", "ourselves": "yourselves",
    "i'm": "you’re", "i've": "you’ve", "i'll": "you’ll", "i'd": "you’d",
    "we're": "you’re", "we've": "you’ve", "we'll": "you’ll", "we'd": "you’d",
  ]

  private static let readerTokens = try? NSRegularExpression(pattern: #"""
    (?x) "[^"]*" | “[^”]*” | ‘[^’]*’ | (?<!\p{L})'[^']+'(?!\p{L})
    | (?<![-'’])\b(?:
      [Ii]\x20(?:am|wasn['’]t|was) | (?i:am|was)\x20[Ii]
      | [Ii]['’](?:m|ve|ll|d) | we['’](?:re|ve|ll|d)
      | [Ii] | me | my(?:self)? | we | us | our(?:selves|s)?
    )\b(?![-'’])
    """#)

  static func addressingUser(_ text: String) -> String {
    let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let readerTokens else { return question }
    // Treat quoted text as a single match so names and direct quotations keep their wording.
    let matches = readerTokens.matches(in: question, range: NSRange(question.startIndex..., in: question))
    var addressed = question
    for match in matches.reversed() {
      guard let range = Range(match.range, in: addressed) else { continue }
      let word = addressed[range].lowercased().replacing("’", with: "'")
      guard let replacement = readerPronouns[word] else { continue }
      let sentenceStart = range.lowerBound == addressed.startIndex
      let rendered = sentenceStart
        ? replacement.prefix(1).uppercased() + replacement.dropFirst()
        : replacement
      addressed.replaceSubrange(range, with: rendered)
    }
    return addressed
  }

  static func comparisonKey(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
      .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  static func hasRepeatedAngle(in questions: [String]) -> Bool {
    let keys = questions.map(comparisonKey)
    let themes = keys.compactMap(recurringTheme)
    let auxiliaryVerbs: Set<Substring> = ["can", "could", "do", "should", "will", "would"]
    let clauses = keys.map { key in
      let parts = key.split(separator: " ", maxSplits: 1)
      guard parts.count == 2, auxiliaryVerbs.contains(parts[0]) else { return key }
      return String(parts[1])
    }
    return Set(themes).count < themes.count || Set(clauses).count < clauses.count
  }

  static func recurringTheme(in normalizedQuestion: String) -> Int? {
    let patterns = [
      #"\b(?:long term (?:impact|outlook|plans?)|life you want|your older self|future self|years from now|what this (?:might|could) make possible|in (?:ten|10) years|when you (?:turn|are) (?:eighty|80))\b"#,
      #"\b(?:nobody knew|if no one (?:knew|was watching)|no pressure to prove)\b"#,
      #"\b(?:smaller version|small scale|trial run|trial period|test run)\b"#,
      #"\b(?:novelty (?:wore|wears) off|newness (?:wore|wears) off)\b"#,
      #"\b(?:stay put|rather stay home|stay where you are|leave things as they are|keep things as they are)\b"#,
    ]
    return patterns.firstIndex { normalizedQuestion.range(of: $0, options: .regularExpression) != nil }
  }

  static func isYesNoQuestion(_ text: String) -> Bool {
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
