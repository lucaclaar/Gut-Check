import Foundation

struct SavedDecision: Identifiable, Codable, Equatable {
  let id: UUID
  let createdAt: Date
  let question: String
  let decision: String
  let feeling: Double
  let answers: [ReflectionAnswer]
  let walks: Int
  var lens: ReflectionLens? = nil
}
