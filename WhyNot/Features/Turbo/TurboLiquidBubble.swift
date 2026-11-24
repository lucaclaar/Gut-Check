import SwiftUI

/// A Turbo option: a Liquid Glass sphere holding the option's brand color. The
/// liquid level is the time the option has left; a save splashes it back up.
struct TurboLiquidBubble: View {
  enum Style: Equatable {
    case live
    /// The last seconds before popping: red rim, wobble and a Popping tag.
    case aboutToPop
    /// What stays behind after an option pops or is let go.
    case ghost(caption: String)
  }

  /// `nil` hides the name, for hero bubbles that sit above the name in large type.
  let title: String?
  let slot: Int
  var level: Double = 0.78
  var style: Style = .live
  var diameter: Double = 130
  /// 1 right after a save, fading to 0; makes the surface splash.
  var splash: Double = 0
  /// Changes on every tap so the liquid springs up instead of jumping.
  var taps = 0
  var interactive = false
  var motionTime: Double?
  var urgency: Double = 0
  var tilt: Double = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var swatch: TurboPalette.Swatch { TurboPalette.swatch(for: slot) }
  private var danger: Bool { style == .aboutToPop }

  var body: some View {
    Group {
      if case .ghost(let caption) = style { ghost(caption) } else { sphere }
    }
    .frame(width: diameter, height: diameter)
    .accessibilityHidden(true)
  }

  private var sphere: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || motionTime != nil)) { context in
      let time = motionTime ?? context.date.timeIntervalSinceReferenceDate
      let wobble = danger && !reduceMotion ? sin(time * 20) * (0.025 + urgency * 0.022) : 0
      ZStack {
        Circle().fill(.linearGradient(colors: [.white.opacity(0.10), .black.opacity(0.28)],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        TurboWater(swatch: swatch, level: level,
          time: reduceMotion ? Double(slot) : time + Double(slot) * 0.57,
          urgency: reduceMotion ? 0 : urgency, splash: reduceMotion ? 0 : splash,
          tilt: reduceMotion ? 0 : tilt)
          .animation(reduceMotion ? nil : .spring(duration: 0.26 - 0.09 * urgency, bounce: 0.24), value: taps)
          .clipShape(.circle)
        specular
        rim
        if let title { label(title) }
      }
      .frame(width: diameter, height: diameter)
      .glassEffect(.clear.interactive(interactive), in: .circle)
      .shadow(color: danger ? TurboPalette.danger.opacity(0.6) : .black.opacity(0.45),
        radius: danger ? 14 : 18, y: danger ? 0 : 12)
      .scaleEffect(x: 1 + wobble, y: 1 - wobble)
    }
    .overlay(alignment: .bottom) {
      if danger { poppingTag.offset(y: 10) }
    }
  }

  private var specular: some View {
    let reflection = Path { path in
      path.addArc(center: CGPoint(x: diameter * 0.5, y: diameter * 0.5),
        radius: diameter * 0.452, startAngle: .degrees(202), endAngle: .degrees(274), clockwise: false)
    }
    return reflection
      .stroke(.linearGradient(colors: [.clear, .white.opacity(0.64), .clear],
        startPoint: .leading, endPoint: .center), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
      .blur(radius: 0.7)
      .allowsHitTesting(false)
  }

  private var rim: some View {
    ZStack {
      Circle().strokeBorder(danger ? TurboPalette.danger : .white.opacity(0.26), lineWidth: danger ? 2.5 : 1)
      Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .clear, .white.opacity(0.4)],
        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        .padding(1)
    }
    .allowsHitTesting(false)
  }

  private func label(_ title: String) -> some View {
    Text(title)
        .font(GutTheme.display(max(11, diameter * 0.1)))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(.black.opacity(0.4), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.2)) }
        .frame(maxWidth: diameter * 0.84)
  }

  private var poppingTag: some View {
    Text("POPPING")
      .font(.system(size: 10, weight: .medium, design: .rounded)).tracking(1)
      .foregroundStyle(Color(red: 0.1, green: 0.016, blue: 0.016))
      .padding(.horizontal, 7).padding(.vertical, 3)
      .background(TurboPalette.danger, in: .rect(cornerRadius: 6))
  }

  private func ghost(_ caption: String) -> some View {
    ZStack {
      Circle().strokeBorder(.white.opacity(0.24), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        .frame(width: diameter * 0.62, height: diameter * 0.62)
      VStack(spacing: 4) {
        if let title {
          Text(title).font(GutTheme.display(12)).strikethrough()
            .foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.6)
        }
        Text(caption.uppercased())
          .font(.system(size: 10, weight: .medium, design: .rounded)).tracking(1.2)
          .foregroundStyle(GutTheme.muted)
      }
      .frame(maxWidth: diameter * 0.56)
    }
  }
}

#Preview {
  HStack(spacing: 24) {
    TurboLiquidBubble(title: "Tacos", slot: 0, level: 0.9)
    TurboLiquidBubble(title: "Pizza", slot: 2, level: 0.12, style: .aboutToPop)
    TurboLiquidBubble(title: "Sushi", slot: 1, style: .ghost(caption: "Popped"))
  }
  .padding()
  .background(GutBackground())
}
