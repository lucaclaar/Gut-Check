import Foundation

nonisolated enum ActivityWidgetStore {
  struct LocalState: Codable, Equatable, Sendable {
    let deviceID: UUID
    let activity: GutActivitySnapshot?
    let steps: Int?
  }

  static let cloudPrefix = "gut-check-activity.v1."

  private static var appGroup: String? {
    let group = Bundle.main.object(forInfoDictionaryKey: "GutCheckActivityAppGroup") as? String
    return group?.isEmpty == false ? group : nil
  }

  static var cloud: NSUbiquitousKeyValueStore? {
    appGroup == nil ? nil : .default
  }

  private static var localURL: URL? {
    guard let appGroup else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appending(path: "activity-widget.json")
  }

  static func readLocal() -> LocalState? {
    guard let localURL, let data = try? Data(contentsOf: localURL) else { return nil }
    return try? JSONDecoder().decode(LocalState.self, from: data)
  }

  static func writeLocal(_ state: LocalState) throws {
    guard let localURL else { throw CocoaError(.fileNoSuchFile) }
    try JSONEncoder().encode(state).write(to: localURL,
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  static func readRemote(excluding deviceID: UUID?) -> [GutActivitySnapshot] {
    guard let cloud else { return [] }
    let ownKey = deviceID.map { cloudPrefix + $0.uuidString }
    return cloud.dictionaryRepresentation.compactMap { key, value in
      guard key.hasPrefix(cloudPrefix), key != ownKey, let data = value as? Data else { return nil }
      return try? JSONDecoder().decode(GutActivitySnapshot.self, from: data)
    }
  }
}
