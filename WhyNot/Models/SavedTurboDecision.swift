import Foundation

struct SavedTurboDecision: Identifiable, Codable, Equatable {
  let id: UUID
  let createdAt: Date
  let choice: String
  let options: [TurboBubble]
  let decidedIn: Double
  let feeling: Double
}
