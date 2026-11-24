import Foundation

nonisolated struct GutActivitySnapshot: Codable, Hashable, Identifiable, Sendable {
  static let widgetKind = "GutCheckActivity"

  enum Stage: Codable, Hashable, Sendable {
    case walk
    case turboCountdown(deadline: Date)
    case turboRound(deadline: Date)
    case turboPaused(secondsLeft: Int)
  }

  let id: UUID
  let startedAt: Date
  let stage: Stage
  let expiresAt: Date

  var isWalk: Bool { stage == .walk }

  var url: URL {
    URL(string: "\(Self.urlScheme)://activity/\(id.uuidString)") ?? Self.homeURL
  }

  private static let urlScheme = Bundle.main.object(forInfoDictionaryKey: "GutCheckActivityURLScheme")
    as? String ?? "gutcheck-activity"

  static let homeURL = URL(string: "\(urlScheme)://home") ?? URL(string: "gutcheck-activity://home")!

  static func id(from url: URL) -> UUID? {
    guard url.scheme == homeURL.scheme, url.host == "activity", url.pathComponents.count == 2,
      let id = url.pathComponents.last else { return nil }
    return UUID(uuidString: id)
  }

  static func current(local: Self?, remote: [Self], at date: Date) -> Self? {
    if let local, date < local.expiresAt { return local }
    return remote.filter { date < $0.expiresAt }.max {
      if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
      return $0.startedAt < $1.startedAt
    }
  }
}
