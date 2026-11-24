import SwiftUI

struct TurboBubbleArena: View {
  let session: TurboSession
  /// Room around each bubble for the red glow and Popping tag of an option about to pop.
  static let edgeAllowance: CGFloat = 10
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var motion: TurboBubbleMotion?
  @State private var drag: (slot: Int, origin: CGPoint, target: CGPoint)?

  var body: some View {
    GeometryReader { proxy in
      let layout = motion.flatMap {
        $0.size == proxy.size && $0.centers.count == session.bubbles.count ? $0 : nil
      } ?? TurboBubbleMotion(size: proxy.size, count: session.bubbles.count,
        ringAllowance: Self.edgeAllowance)
      let urgency = session.urgency
      let levels = session.reserves
      let waterTime = session.rules.depletion(at: session.elapsed)
      ZStack {
        ForEach(session.bubbles) { bubble in
          let slot = bubble.slot
          TurboBubbleView(bubble: bubble, diameter: layout.diameter,
            reserve: levels[slot],
            aboutToPop: session.isAboutToPop(bubble),
            splash: max(0, 1 - (session.elapsed - bubble.lastRescuedAt) / (0.46 - 0.16 * urgency)),
            waterTime: waterTime, urgency: urgency, tilt: waterTilt(for: slot, diameter: layout.diameter),
            save: { session.save(bubble.id) }, choose: { session.choose(bubble.id) },
            discard: { session.discard(bubble.id) },
            dragChanged: { changeDrag($0, slot: slot, center: layout.centers[slot]) })
            .position(layout.centers[slot])
        }
      }
      .onChange(of: proxy.size) { _, _ in
        motion = layout
        drag = nil
      }
      .onChange(of: session.phase) { _, phase in
        if phase != .playing { drag = nil }
      }
      .onChange(of: session.elapsed) { _, elapsed in
        guard session.phase == .playing else { return }
        var updated = layout
        updated.advance(to: elapsed, activeSlots: session.activeBubbles.map(\.slot),
          drag: drag.map { ($0.slot, $0.target) }, reduceMotion: reduceMotion)
        motion = updated
      }
    }
  }

  private func waterTilt(for slot: Int, diameter: CGFloat) -> Double {
    guard let drag, drag.slot == slot else { return 0 }
    return min(0.26, max(-0.26, (drag.target.x - drag.origin.x) * -0.65 / max(1, diameter)))
  }

  private func changeDrag(_ translation: CGSize?, slot: Int, center: CGPoint) {
    guard session.phase == .playing, let translation else {
      if drag?.slot == slot { drag = nil }
      return
    }
    let origin = drag?.slot == slot ? drag?.origin ?? center : center
    drag = (slot, origin, CGPoint(x: origin.x + translation.width, y: origin.y + translation.height))
  }
}
