import Foundation

struct ReflectionWalkDraft: Codable {
  let request: WalkExchange.Request?
  let question: String
  let lens: ReflectionLens
  let answers: [ReflectionAnswer]
  let walks: Int
  let finishedSteps: Int?
  var cards: [ReflectionQuestion]? = nil
  var cardIndex: Int? = nil
  var personalizedCards: Bool? = nil
  var path: [ReflectionRoute]? = nil
  var decisionID: UUID? = nil
  var decision: String? = nil
  var feeling: Double? = nil
  var needsMoreTime: Bool? = nil
  var walkCompletions: [WalkExchange.Completion]? = nil
}
