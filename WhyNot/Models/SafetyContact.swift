import Foundation

struct SafetyContact: Decodable, Identifiable {
  let id: String
  let countryCodes: [String]
  let kind: String
  let name: String
  let phone: String
  let callURL: URL
  let hours: String?
  let website: URL
  let source: String
  let verifiedOn: String

  var isEmergency: Bool { kind == "emergency" }

  var dialingURL: URL {
    // Preserve the verified source URL in the catalog, but pass only the phone
    // number to the system dialer (no attribution query or fragment).
    guard var components = URLComponents(url: callURL, resolvingAgainstBaseURL: false) else {
      return callURL
    }
    components.query = nil
    components.fragment = nil
    return components.url ?? callURL
  }
}
