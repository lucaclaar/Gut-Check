import Foundation

/// A small, deterministic first layer, not a clinical assessment. It runs offline before
/// the card flow. A future model may escalate a result, but must not remove this gate
/// or generate contact details. No text is sent to a service or logged here.
enum SafetyScreening {
  static func concern(in text: String) -> SafetyConcern? {
    let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
      .replacingOccurrences(of: "’", with: "'")
    let clauses = normalized.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
      .flatMap { $0.components(separatedBy: " ma ") }
      .flatMap { $0.components(separatedBy: " but ") }

    var results: [SafetyConcern] = []
    for raw in clauses {
      // Remove specific negated statements, never an entire message containing "non".
      var clause = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
      for phrase in ["non voglio uccidermi", "non voglio suicidarmi", "non voglio morire",
        "non voglio farmi del male", "non voglio farmi male", "non voglio farla finita",
        "non voglio ammazzarmi", "non sono suicida", "non ho pensieri suicidi", "non ho pensieri di suicidio",
        "i don't want to kill myself", "i do not want to kill myself", "i am not suicidal",
        "i'm not suicidal", "i don't want to die", "i do not want to die",
        "i don't want to hurt myself", "i do not want to hurt myself"] {
        clause = clause.replacingOccurrences(of: phrase, with: "")
      }
      // Do not treat a clearly educational or fictional mention as a disclosure.
      let contextual = ["sto scrivendo una tesi", "sto studiando", "nel romanzo", "nel film",
        "per un esame", "writing an essay", "in the novel", "in the movie"]
      let personal = ["voglio uccidermi", "voglio suicidarmi", "voglio farmi del male",
        "voglio morire", "kill myself", "hurt myself", "want to die", "mi hanno accoltellato"]
      if contains(contextual, in: clause) && !contains(personal, in: clause) { continue }
      if contains(["suicid", "uccidermi", "uccidersi", "ammazzarmi", "farmi del male", "farmi male", "farsi del male", "farla finita",
        "voglio morire", "non voglio piu vivere", "non ce la faccio piu a vivere",
        "mi taglio", "mi sto tagliando", "kill myself", "end my life", "want to die",
        "hurt myself", "kill himself", "kill herself", "kill themselves",
        "self harm", "self-harm", "cutting myself", "don't want to live",
        "do not want to live"], in: clause) {
        results.append(.selfHarm)
      }
      if contains(["accoltell", "mi sta picchiando", "mi ha picchiato", "mi vuole uccidere",
        "voglio uccidere", "voglio ammazzare", "mi minaccia", "sono in pericolo",
        "domestic violence", "being stabbed", "been stabbed", "stab someone", "stabbing",
        "kill someone", "kill him", "kill her", "threatening me", "hitting me",
        "i am in danger", "i'm in danger", "mi sento in pericolo"], in: clause) {
        results.append(.violence)
      }
      if contains(["non riesco a respirare", "non riesco piu a respirare", "dolore al petto", "sto sanguinando",
        "non smette di sanguinare", "troppe pillole", "overdose", "avvelenamento",
        "non respira", "cannot breathe", "can't breathe", "chest pain", "bleeding heavily",
        "won't stop bleeding", "too many pills", "not breathing", "poisoning"], in: clause) {
        results.append(.medical)
      }
    }
    // An injury or overdose needs emergency contacts even if self-harm was also mentioned.
    if results.contains(.medical) { return .medical }
    if results.contains(.violence) { return .violence }
    return results.first
  }

  private static func contains(_ phrases: [String], in text: String) -> Bool {
    phrases.contains { text.contains($0) }
  }
}
