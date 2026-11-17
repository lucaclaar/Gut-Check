import SwiftUI

enum ReflectionLens: String, CaseIterable, Codable, Identifiable {
  case mixed, best, worst
  var id: String { rawValue }
  var title: String {
    switch self {
    case .mixed: "Mixed"
    case .best: "Best case"
    case .worst: "Worst case"
    }
  }
  var subtitle: String {
    switch self {
    case .mixed: "A bit of\nboth"
    case .best: "What if it\ngoes great?"
    case .worst: "What could\ngo wrong?"
    }
  }
  var color: Color {
    switch self {
    case .mixed: GutTheme.purple
    case .best: GutTheme.yellow
    case .worst: GutTheme.orange
    }
  }
  var mascot: String {
    switch self {
    case .mixed: "MascotMixedEmotions1"
    case .best: "MascotBestCase2"
    case .worst: "MascotWorstCase4"
    }
  }
}
