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
  var savesLeft: Int?
  var diameter: Double = 130
  /// 1 right after a save, fading to 0; makes the surface splash.
  var splash: Double = 0
  var interactive = false
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
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      let wobble = danger && !reduceMotion ? sin(time * 18) * 0.05 : 0
      ZStack {
        liquid(time).clipShape(.circle)
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

  private func liquid(_ time: Double) -> some View {
    let phase = reduceMotion ? Double(slot) : time * 2.4 + Double(slot) * 1.7
    let amplitude = diameter * (0.025 + 0.05 * splash)
    let level = min(1, max(0, self.level))
    return ZStack {
      LiquidWave(level: min(1, level + 0.035), phase: phase + 1.4, amplitude: amplitude)
        .fill(swatch.crest)
      LiquidWave(level: level, phase: phase, amplitude: amplitude)
        .fill(LinearGradient(stops: [
          .init(color: swatch.color, location: 0), .init(color: swatch.color, location: 0.15),
          .init(color: swatch.deep, location: 1),
        ], startPoint: .top, endPoint: .bottom))
    }
    .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.35), value: savesLeft)
  }

  private var specular: some View {
    Ellipse()
      .fill(RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0)], center: .center,
        startRadius: 0, endRadius: diameter * 0.24))
      .frame(width: diameter * 0.48, height: diameter * 0.26)
      .offset(x: -diameter * 0.16, y: -diameter * 0.3)
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
    VStack(spacing: 6) {
      Text(title)
        .font(GutTheme.display(max(11, diameter * 0.1)))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(.black.opacity(0.4), in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.2)) }
      if let savesLeft {
        HStack(spacing: 3) {
          ForEach(0..<3, id: \.self) { index in
            Capsule().fill(.white.opacity(index < savesLeft ? 1 : 0.3)).frame(width: 9, height: 4)
          }
        }
      }
    }
    .frame(maxWidth: diameter * 0.84)
    .offset(y: savesLeft == nil ? 0 : 5)
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

/// The liquid inside a bubble: a gentle sine wave at the given fill level.
nonisolated struct LiquidWave: Shape {
  var level: Double
  var phase: Double
  var amplitude: Double

  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(level, amplitude) }
    set { level = newValue.first; amplitude = newValue.second }
  }

  func path(in rect: CGRect) -> Path {
    let surface = rect.height * (1 - level)
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
      let angle = (x / rect.width) * 2 * .pi * 1.1 + phase
      path.addLine(to: CGPoint(x: x, y: surface + sin(angle) * amplitude))
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

#Preview {
  HStack(spacing: 24) {
    TurboLiquidBubble(title: "Tacos", slot: 0, level: 0.9, savesLeft: 3)
    TurboLiquidBubble(title: "Pizza", slot: 2, level: 0.12, style: .aboutToPop, savesLeft: 1)
    TurboLiquidBubble(title: "Sushi", slot: 1, style: .ghost(caption: "Popped"))
  }
  .padding()
  .background(GutBackground())
}
