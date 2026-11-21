import Foundation

struct ReflectionFollowUp {
  let answers: [ReflectionAnswer]
  let seen: [ReflectionQuestion]
  let userIsUnsure: Bool

  /// Cap the material sent to the model. The complete history is still used to reject repeats.
  var recentAnswers: [ReflectionAnswer] { Array(answers.suffix(18)) }

  func standardDeck(for lens: ReflectionLens) -> [ReflectionQuestion] {
    let practical = [
      "Would setting a firm spending limit change your answer?",
      "Would the timing work better if you picked a different day?",
      "Could you try a smaller version first?",
      "Would this still fit alongside what you’ve already promised?",
      "Would getting one missing detail be enough to make the choice?",
      "Could you put a deadline on when to decide?",
      "Would splitting the effort with someone make the idea workable?",
      "Could you keep the door open without committing today?",
    ]
    let positive = [
      "Would making this choice give you more room to be yourself?",
      "Would making this choice let you spend more time on what matters right now?",
      "Would you choose this option if there were no pressure to prove anything?",
      "Would you be comfortable making the same choice twice?",
      "Would choosing this option help you practice a skill you care about?",
      "Would you want this option even if the novelty wore off?",
      "Would the smallest benefit still matter to you?",
      "Would you tell someone close to you about this with excitement?",
    ]
    let downside = [
      "Would choosing this leave you too little time to rest?",
      "Would someone you care about need more notice than you can give?",
      "Would it bother you to give up the alternative?",
      "Would this choice make you rely on something outside your control?",
      "Would you feel uneasy if the choice became permanent?",
      "Would the downside fall mostly on someone else?",
      "Would the choice conflict with a boundary you want to keep?",
      "Would changing your mind later carry a cost you’d want to avoid?",
    ]

    let consideringTradeOffs =
      userIsUnsure || ReflectionInsight.offline(from: answers).leaning == .mixed
    let alternatives: [String]
    switch lens {
    case .mixed:
      let balanced = zip(positive, downside).flatMap { [$0.0, $0.1] }
      alternatives = consideringTradeOffs ? practical + balanced : balanced + practical
    case .best:
      alternatives =
        consideringTradeOffs
        ? Array(practical.prefix(2)) + positive + practical.dropFirst(2)
        : positive + practical
    case .worst:
      alternatives =
        consideringTradeOffs
        ? Array(practical.prefix(2)) + downside + practical.dropFirst(2)
        : downside + practical
    }
    return deck(freshQuestions(from: alternatives), for: lens)
  }

  func generatedDeck(_ questions: [String], for lens: ReflectionLens) -> [ReflectionQuestion]? {
    guard questions.count == 4 else { return nil }
    let fresh = freshQuestions(from: questions)
    return fresh.count >= 2 ? deck(fresh, for: lens) : nil
  }

  private func freshQuestions(from candidates: [String]) -> [String] {
    var fresh: [String] = []
    let previous = seen.map(\.text)
    for candidate in candidates {
      let question = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
      guard ReflectionQuestion.isYesNoQuestion(question),
        SafetyScreening.concern(in: question) == nil,
        question.range(
          of:
            #"(?i)\b(?:specific condition|specific delay|concrete risk|reversible test|smaller version of|practical step|confirm readiness|shift the decision)\b"#,
          options: .regularExpression) == nil,
        isNew(question, comparedWith: previous + fresh)
      else { continue }
      fresh.append(question)
      if fresh.count == 4 { break }
    }
    return fresh
  }

  private func deck(_ texts: [String], for lens: ReflectionLens) -> [ReflectionQuestion] {
    let firstID = max(999, seen.map(\.id).max() ?? 0) + 1
    let templates = ReflectionQuestion.deck(for: lens)
    return texts.enumerated().map { offset, text in
      let template = templates[offset]
      return ReflectionQuestion(
        id: firstID + offset, lens: template.lens, eyebrow: "A CLOSER LOOK",
        text: text, mascot: template.mascot)
    }
  }

  private func isNew(_ question: String, comparedWith previous: [String]) -> Bool {
    let normalize: (String) -> String = { text in
      text.folding(
        options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en")
      )
      .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
      .joined(separator: " ")
    }
    let normalized = normalize(question)
    let words = meaningfulWords(in: normalized)
    let theme = repeatedTheme(in: normalized)
    return !previous.contains { other in
      let normalizedOther = normalize(other)
      if normalizedOther == normalized
        || (theme != nil && theme == repeatedTheme(in: normalizedOther))
      {
        return true
      }
      let otherWords = meaningfulWords(in: normalizedOther)
      let shared = words.intersection(otherWords).count
      return (shared >= 2 && words == otherWords)
        || (shared >= 3 && shared * 3 >= words.union(otherWords).count * 2)
    }
  }

  private func repeatedTheme(in text: String) -> Int? {
    let patterns = [
      #"\b(?:long term|life you want|your older self|future self|years from now|what this (?:might|could) make possible|in (?:ten|10) years)\b"#,
      #"\b(?:nobody knew|if no one (?:knew|was watching)|no pressure to prove)\b"#,
      #"\b(?:smaller version|small scale|trial run|trial period|test run)\b"#,
      #"\b(?:novelty (?:wore|wears) off|newness (?:wore|wears) off)\b"#,
      #"\b(?:stay put|rather stay home|stay where you are|leave things as they are|keep things as they are)\b"#,
    ]
    return patterns.firstIndex { text.range(of: $0, options: .regularExpression) != nil }
  }

  private func meaningfulWords(in text: String) -> Set<Substring> {
    let plain = text.replacingOccurrences(of: "spending limit", with: "budget")
      .replacingOccurrences(of: "budget cap", with: "budget")
    let common: Set<Substring> = [
      "would", "could", "should", "this", "that", "your", "have", "about", "with", "were", "there",
      "enough", "choice", "option", "choose", "choosing", "make", "making", "decide", "answer",
    ]
    return Set(plain.split(separator: " ").filter { $0.count > 3 && !common.contains($0) })
  }
}
