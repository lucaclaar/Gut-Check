import SwiftUI

/// Gut Check brand palette for Turbo options, in the order options take it so the
/// first options are always the strongest contrast pairs: Dare Devil, Electric,
/// Gold, Royal, Arctic, then a lighter Dare Devil for a sixth option.
enum TurboPalette {
  struct Swatch {
    /// The pure brand color at the top of the liquid.
    let color: Color
    /// A deeper shade toward the bottom of the liquid, for depth.
    let deep: Color
    /// A lighter tint for the liquid's surface.
    let crest: Color
  }

  private static let swatches: [Swatch] = [
    Swatch(color: hex(0xFF5B22), deep: hex(0xD93E0B), crest: hex(0xFF9C78)),
    Swatch(color: hex(0x3939FF), deep: hex(0x1F1FC4), crest: hex(0x8C8CFF)),
    Swatch(color: hex(0xF2BB05), deep: hex(0xC99600), crest: hex(0xF7D768)),
    Swatch(color: hex(0xDBB8FF), deep: hex(0xA97FE8), crest: hex(0xECDDFF)),
    Swatch(color: hex(0xAEE6ED), deep: hex(0x6CC3CF), crest: hex(0xD6F4F7)),
    Swatch(color: hex(0xFF8A5C), deep: hex(0xFF5B22), crest: hex(0xFFC2A8)),
  ]

  static func swatch(for slot: Int) -> Swatch { swatches[max(0, slot) % swatches.count] }
  static func color(for slot: Int) -> Color { swatch(for: slot).color }
  /// Readable text on a solid swatch: white on Electric, dark ink on the lighter colors.
  static func textColor(for slot: Int) -> Color {
    max(0, slot) % swatches.count == 1 ? .white : Color(red: 0.1, green: 0.07, blue: 0.12)
  }

  /// Red used when an option is about to pop and for the repeated-option error.
  static let danger = hex(0xFF3B4E)
  static let dangerText = hex(0xFF8574)

  private static func hex(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}
