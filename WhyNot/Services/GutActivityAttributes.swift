import ActivityKit
import Foundation

nonisolated struct GutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable, Sendable {
    let snapshot: GutActivitySnapshot
    let steps: Int?
  }

  let id: UUID
}
