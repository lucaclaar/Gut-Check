import SwiftUI

struct TurboBurstView: View {
  let diameter: Double
  let tint: Color
  @State private var expanded = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle().strokeBorder(tint, lineWidth: 2)
        .frame(width: diameter, height: diameter)
        .scaleEffect(expanded && !reduceMotion ? 1.42 : 1)
      if !reduceMotion {
        ForEach(0..<8) { index in
          let angle = Double(index) * .pi / 4
          let distance = diameter * (expanded ? 0.68 : 0.38)
          Circle().fill(tint).frame(width: 5, height: 5)
            .offset(x: cos(angle) * distance, y: sin(angle) * distance)
        }
      }
    }
    .opacity(expanded ? 0 : 0.9)
    .onAppear { withAnimation(.easeOut(duration: 0.32)) { expanded = true } }
    .allowsHitTesting(false).accessibilityHidden(true)
  }
}
