import Foundation

struct TurboBubble: Identifiable, Codable, Equatable {
  let id: UUID
  let text: String
  let slot: Int
  /// Successful saves (at most `TurboRules.savesPerOption`).
  var rescues = 0
  /// Every tap, including refused ones once the saves are used up.
  var taps = 0
  /// Saves made with `TurboRules.lastSecondWindow` or less left.
  var lastSecondSaves = 0
  var isPopped = false
  var isDiscarded = false
  /// Round time at which the option popped or was let go.
  var endedAt: Double?
  var lastRescuedAt: Double = -10

  init(id: UUID, text: String, slot: Int) {
    self.id = id
    self.text = text
    self.slot = slot
  }

  // Records saved by the earlier Turbo only contain id, text, slot, rescues and isPopped.
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    text = try values.decode(String.self, forKey: .text)
    slot = try values.decode(Int.self, forKey: .slot)
    rescues = try values.decodeIfPresent(Int.self, forKey: .rescues) ?? 0
    taps = try values.decodeIfPresent(Int.self, forKey: .taps) ?? rescues
    lastSecondSaves = try values.decodeIfPresent(Int.self, forKey: .lastSecondSaves) ?? 0
    isPopped = try values.decodeIfPresent(Bool.self, forKey: .isPopped) ?? false
    isDiscarded = try values.decodeIfPresent(Bool.self, forKey: .isDiscarded) ?? false
    endedAt = try values.decodeIfPresent(Double.self, forKey: .endedAt)
    lastRescuedAt = try values.decodeIfPresent(Double.self, forKey: .lastRescuedAt) ?? -10
  }
}
