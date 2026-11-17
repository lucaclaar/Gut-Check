import Foundation

struct ReflectionAnswer: Identifiable, Codable, Equatable {
  var id: Int { question.id }
  let question: ReflectionQuestion
  var yes: Bool
}
