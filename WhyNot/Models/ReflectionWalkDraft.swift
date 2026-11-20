import Foundation

struct ReflectionWalkDraft: Codable {
  let request: WalkExchange.Request
  let question: String
  let lens: ReflectionLens
  let answers: [ReflectionAnswer]
  let walks: Int
  let finishedSteps: Int?
  var cards: [ReflectionQuestion]? = nil
  var cardIndex: Int? = nil
}
