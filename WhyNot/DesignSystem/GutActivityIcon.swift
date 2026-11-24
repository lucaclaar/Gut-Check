import SwiftUI
import WidgetKit

struct GutActivityIcon: View {
  let snapshot: GutActivitySnapshot
  var steps: Int?
  var diameter: CGFloat = 38
  var showsProgress = true

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  private var stride: Int { (steps ?? 0) / 25 }
  private var animateStride: Bool { stride > 0 && !reduceMotion && !luminanceReduced }

  var body: some View {
    if snapshot.isWalk {
      ZStack {
        if showsProgress, let steps {
          Circle().strokeBorder(Color("GutRingTrack"), lineWidth: 3)
          Circle().inset(by: 1.5).trim(from: 0, to: min(1, Double(steps) / Double(WalkExchange.goal)))
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .privacySensitive()
        }

        let artworkSize = diameter - (showsProgress && steps != nil ? 12 : 2)
        Image(decorative: artworkSize <= 24 ? "WalkMascotCompact" : "WalkMascot")
          .resizable()
          .widgetAccentedRenderingMode(.fullColor)
          .scaledToFit()
          .frame(width: artworkSize, height: artworkSize)
          .rotationEffect(.degrees(animateStride ? (stride.isMultiple(of: 2) ? 5 : -5) : 0))
          .offset(y: animateStride && !stride.isMultiple(of: 2) ? -1.5 : 0)
          .animation(reduceMotion || luminanceReduced ? nil : .spring(duration: 0.3), value: stride)
      }
      .frame(width: diameter, height: diameter)
    } else {
      Image(systemName: snapshot.symbol)
        .font(.title3.weight(.semibold)).foregroundStyle(snapshot.tint)
    }
  }
}
