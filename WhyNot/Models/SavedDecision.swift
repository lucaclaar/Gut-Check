import Foundation

struct SavedDecision: Identifiable, Codable, Equatable {
  let id: UUID
  let createdAt: Date
  let question: String
  let decision: String
  let feeling: Double
  let answers: [ReflectionAnswer]
  var walks: Int
  var lens: ReflectionLens? = nil
  var isDeferred: Bool? = nil
  var walkCompletions: [WalkExchange.Completion]? = nil
}
