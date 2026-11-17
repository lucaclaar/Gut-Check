import Foundation

enum SafetyChecks {
  static func run() throws {
    let examples: [(String, SafetyConcern?)] = [
      ("Should I take the job in Barcelona?", nil),
      ("Voglio suicidarmi", .selfHarm),
      ("Non voglio più vivere", .selfHarm),
      ("Penso di farmi del male", .selfHarm),
      ("I want to kill myself", .selfHarm),
      ("I don't want to live anymore", .selfHarm),
      ("Non voglio uccidermi", nil),
      ("I am not suicidal", nil),
      ("I don't want to die", nil),
      ("Non sono suicida", nil),
      ("Voglio farmi male", .selfHarm),
      ("Mio fratello vuole uccidersi", .selfHarm),
      ("Non riesco più a respirare", .medical),
      ("Ho dolore   al petto", .medical),
      ("Non voglio uccidermi, ma ho preso troppe pillole", .medical),
      ("Sto scrivendo una tesi sul suicidio per un esame", nil),
      ("Nel romanzo c'è un accoltellamento", nil),
      ("Sto studiando ma voglio suicidarmi", .selfHarm),
      ("Mi hanno accoltellato", .violence),
      ("Mi sta picchiando", .violence),
      ("He is threatening me", .violence),
      ("Voglio uccidere qualcuno", .violence),
      ("Ho dolore al petto e non riesco a respirare", .medical),
      ("I can't breathe", .medical),
      ("Ho preso troppe pillole per uccidermi", .medical),
      ("Devo prenotare una visita dal medico", nil),
      ("Mi fa morire dal ridere", nil),
      ("Vorrei tagliare i capelli", nil),
    ]
    for (text, expected) in examples {
      precondition(SafetyScreening.concern(in: text) == expected, "Unexpected safety classification in a fixture")
    }

    let model = ReflectionSession(storageURL: .temporaryDirectory.appending(path: UUID().uuidString))
    model.start()
    model.question = "Voglio suicidarmi"
    model.shuffle()
    precondition(model.path == [.setup] && model.safetyConcern == .selfHarm)
    model.safetyConcern = nil
    model.checkSafety()
    precondition(model.safetyConcern == nil, "Partial transcripts must not continually reopen an acknowledged sheet")
    model.shuffle()
    precondition(model.path == [.setup] && model.safetyConcern == .selfHarm, "Dismissal must not bypass screening")
    model.safetyConcern = nil
    model.keepReflecting()
    precondition(model.path == [.setup] && model.safetyConcern == .selfHarm)
    model.question = "Should I move to Barcelona?"
    model.safetyConcern = nil
    model.checkSafety()
    model.shuffle()
    precondition(model.path.last == .cards)
    model.question = "Voglio suicidarmi"
    model.checkSafety()
    precondition(model.safetyConcern == .selfHarm, "A new disclosure after a safe question must reopen support")
    model.start()
    model.checkSafety()
    precondition(model.safetyConcern == .selfHarm, "A new session must reset the automatic presentation guard")

    let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let directory = try JSONDecoder().decode(SafetyDirectory.self, from: Data(contentsOf: fixtureURL))
    precondition(directory.contacts(for: "IT").map(\.phone) == ["112", "02 2327 2327"])
    precondition(directory.contacts(for: "US").first?.phone == "911")
    precondition(directory.contacts(for: "AU").first?.phone == "000")
    precondition(directory.contacts(for: "NZ").first?.phone == "111")
    precondition(directory.contacts(for: "GB").first?.phone == "999")
    precondition(directory.contacts(for: "FR").first?.phone == "112")
    precondition(directory.contacts(for: "JP").isEmpty && directory.contacts(for: "").isEmpty,
      "Unknown countries must not inherit another country's number")
    precondition(directory.contacts(for: "it").count == 2)
    precondition(directory.contacts.first { $0.id == "it-telefono-amico" }?.hours == nil,
      "Unverified opening hours must remain unknown")
    precondition(Set(directory.contacts.flatMap(\.countryCodes)).count == 32)
    precondition(SafetyDirectory.suggestedCountry(locale: Locale(identifier: "it_IT")) == "IT")
    precondition(SafetyDirectory.suggestedCountry(locale: Locale(identifier: "en_US")) == "US")
    precondition(SafetyDirectory.suggestedCountry(locale: Locale(identifier: "en")) == "")
    for contact in directory.contacts {
      precondition(contact.callURL.scheme == "tel" && contact.website.scheme == "https")
      precondition(contact.dialingURL.scheme == "tel" && !contact.dialingURL.absoluteString.contains("?"))
      let dial = contact.callURL.absoluteString.dropFirst(4).split(separator: "?")[0]
      precondition(dial.allSatisfy { $0.isNumber || $0 == "+" }, "Call URLs must contain only phone digits")
      precondition(String(dial).filter(\.isNumber) == contact.phone.filter(\.isNumber)
        || String(dial) == "+39" + contact.phone.filter(\.isNumber))
      precondition(contact.dialingURL.absoluteString == "tel:" + dial)
      precondition(!contact.source.isEmpty && !contact.verifiedOn.isEmpty)
    }
    print("Safety checks passed: screening fixtures, flow gates, country selection and contact catalog")
  }
}
