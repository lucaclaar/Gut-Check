import Foundation

struct SafetyDirectory: Decodable {
  let version: Int
  let contacts: [SafetyContact]

  static let bundled: SafetyDirectory = {
    guard let url = Bundle.main.url(forResource: "SafetyContacts", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let directory = try? JSONDecoder().decode(SafetyDirectory.self, from: data)
    else { return SafetyDirectory(version: 1, contacts: []) }
    return directory
  }()

  func contacts(for countryCode: String) -> [SafetyContact] {
    contacts.filter { $0.countryCodes.contains(countryCode.uppercased()) }
      .sorted { $0.isEmergency && !$1.isEmergency }
  }

  static func suggestedCountry(locale: Locale = .autoupdatingCurrent) -> String {
    locale.region?.identifier ?? ""
  }

  static func countryName(_ code: String) -> String {
    Locale(identifier: "en").localizedString(forRegionCode: code) ?? code
  }
}
