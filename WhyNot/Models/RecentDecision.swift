import Foundation

struct RecentDecision: Identifiable {
  let id: UUID
  let title: String
  let feeling: Double
  let createdAt: Date

  static func latest(reflect: [SavedDecision], turbo: [SavedTurboDecision]) -> [Self] {
    let reflections = reflect.map { Self(id: $0.id, title: $0.decision, feeling: $0.feeling, createdAt: $0.createdAt) }
    let turboPicks = turbo.map { Self(id: $0.id, title: $0.choice, feeling: $0.feeling, createdAt: $0.createdAt) }
    return Array((reflections + turboPicks).sorted { $0.createdAt > $1.createdAt }.prefix(2))
  }
}
