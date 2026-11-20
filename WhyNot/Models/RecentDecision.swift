import Foundation

struct RecentDecision: Identifiable {
  let id: UUID
  let title: String
  enum Mode { case reflect, turbo }

  let mode: Mode
  let createdAt: Date

  static func newestFirst(reflect: [SavedDecision], turbo: [SavedTurboDecision]) -> [Self] {
    let reflections = reflect.map {
      Self(id: $0.id, title: $0.isDeferred == true ? $0.question : $0.decision,
        mode: .reflect, createdAt: $0.createdAt)
    }
    let turboPicks = turbo.map { Self(id: $0.id, title: $0.choice, mode: .turbo, createdAt: $0.createdAt) }
    return (reflections + turboPicks).sorted { $0.createdAt > $1.createdAt }
  }
}
