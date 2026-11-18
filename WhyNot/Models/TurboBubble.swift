import Foundation

struct TurboBubble: Identifiable, Codable, Equatable {
  let id: UUID
  let text: String
  let slot: Int
  var rescues = 0
  var isPopped = false
  var lastRescuedAt: Double = -10
}
