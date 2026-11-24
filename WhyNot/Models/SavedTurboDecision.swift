import Foundation

struct SavedTurboDecision: Identifiable, Codable, Equatable {
  let id: UUID
  let createdAt: Date
  /// The final choice. Empty for an unfinished decision.
  let choice: String
  let options: [TurboBubble]
  let decidedIn: Double
  /// Absent when the person skips the rating or saves an unfinished round.
  let feeling: Double?
  /// What the round picked when the person switched to the runner-up afterwards.
  var gutPick: String?
  /// Saved for later from the options screen or a paused round.
  var isUnfinished = false

  init(id: UUID, createdAt: Date, choice: String, options: [TurboBubble], decidedIn: Double,
    feeling: Double?, gutPick: String? = nil, isUnfinished: Bool = false) {
    self.id = id
    self.createdAt = createdAt
    self.choice = choice
    self.options = options
    self.decidedIn = decidedIn
    self.feeling = feeling
    self.gutPick = gutPick
    self.isUnfinished = isUnfinished
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    createdAt = try values.decode(Date.self, forKey: .createdAt)
    choice = try values.decode(String.self, forKey: .choice)
    options = try values.decode([TurboBubble].self, forKey: .options)
    decidedIn = try values.decode(Double.self, forKey: .decidedIn)
    feeling = try values.decodeIfPresent(Double.self, forKey: .feeling)
    gutPick = try values.decodeIfPresent(String.self, forKey: .gutPick)
    isUnfinished = try values.decodeIfPresent(Bool.self, forKey: .isUnfinished) ?? false
  }

  var title: String {
    isUnfinished ? options.sorted { $0.slot < $1.slot }.map(\.text).joined(separator: " · ") : choice
  }
}
