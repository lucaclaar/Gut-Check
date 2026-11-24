import SwiftUI

/// Draws the water inside the glass. Only the fill level is spring-animated; the
/// surface and bubbles follow the round's clock, so they freeze on pause.
struct TurboWater: View, Animatable {
  let swatch: TurboPalette.Swatch
  var level: Double
  let time: Double
  let urgency: Double
  let splash: Double
  let tilt: Double

  var animatableData: Double {
    get { level }
    set { level = newValue }
  }

  var body: some View {
    Canvas { context, size in
      let level = min(1, max(0, level))
      guard level > 0, size.width > 0, size.height > 0 else { return }
      let width = size.width
      let height = size.height
      let waterline = (1 - level) * height
      let amplitude = height * (0.008 + 0.012 * urgency + 0.045 * splash)
      let phase = time * 3.2

      func surface(at x: Double, rear: Bool = false) -> Double {
        let u = x / width
        let meniscus = height * 0.028 * pow(abs(u * 2 - 1), 4)
        let wave = sin(u * 7 - phase + (rear ? 1.7 : 0))
          + 0.34 * sin(u * 14 + phase * 0.68)
        let surface = waterline + wave * amplitude - meniscus + height * (u - 0.5) * tilt
          - (rear ? height * 0.027 : 0)
        return min(height, max(0, surface))
      }

      func edge(rear: Bool = false) -> Path {
        Path { path in
          path.move(to: CGPoint(x: 0, y: surface(at: 0, rear: rear)))
          for step in 1...32 {
            let x = width * Double(step) / 32
            path.addLine(to: CGPoint(x: x, y: surface(at: x, rear: rear)))
          }
        }
      }

      func volume(below edge: Path) -> Path {
        var path = edge
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
      }

      let front = edge()
      let body = volume(below: front)
      let surfaceStart = CGPoint(x: width * 0.16, y: waterline)
      let bottom = CGPoint(x: width * 0.7, y: height)
      context.fill(volume(below: edge(rear: true)), with: .linearGradient(
        Gradient(colors: [swatch.crest.opacity(0.82), swatch.deep.opacity(0.55)]),
        startPoint: surfaceStart, endPoint: bottom))
      context.fill(body, with: .linearGradient(
        Gradient(stops: [
          .init(color: swatch.crest.opacity(0.92), location: 0),
          .init(color: swatch.color.opacity(0.77), location: 0.24),
          .init(color: swatch.deep.opacity(0.90), location: 0.8),
          .init(color: swatch.deep.mix(with: .black, by: 0.35), location: 1),
        ]), startPoint: surfaceStart, endPoint: bottom))

      var submerged = context
      submerged.clip(to: body)
      submerged.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
        Gradient(colors: [swatch.crest.opacity(0.53), swatch.crest.opacity(0)]),
        center: CGPoint(x: width * 0.77, y: waterline + height * 0.18),
        startRadius: 0, endRadius: width * 0.52))

      // Narrow bands of reflected light move under the surface.
      for band in 0..<3 {
        let left = width * (0.08 + Double(band) * 0.09)
        let right = width * (0.86 - Double(band) * 0.08)
        let depth = height * (0.04 + Double(band) * 0.11)
        let offset = sin(phase * 0.6 + Double(band) * 2.2) * depth * 0.3
        let reflection = Path { path in
          path.move(to: CGPoint(x: left, y: surface(at: left) + depth))
          path.addQuadCurve(to: CGPoint(x: right, y: surface(at: right) + depth * 0.72),
            control: CGPoint(x: width * 0.61, y: waterline + depth * 0.25 + offset))
        }
        submerged.stroke(reflection, with: .linearGradient(
          Gradient(colors: [.white.opacity(0), .white.opacity(0.27 - Double(band) * 0.065), .white.opacity(0)]),
          startPoint: CGPoint(x: left, y: 0), endPoint: CGPoint(x: right, y: 0)), lineWidth: 0.75)
      }

      for index in 0..<7 {
        let seed = Double(index)
        let cycle = time * (0.22 + seed * 0.025) + seed * 0.37
        let rise = cycle - floor(cycle)
        let x = width * (0.18 + seed * 0.105 + 0.026 * sin(phase * 0.42 + seed))
        let y = height - (height - surface(at: x)) * rise
        let radius = width * (0.009 + 0.004 * Double(index % 3))
        let alpha = sin(rise * .pi) * 0.57
        let air = Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
          width: 2 * radius, height: 2 * radius))
        submerged.fill(air, with: .color(swatch.deep.opacity(alpha * 0.36)))
        submerged.stroke(air, with: .linearGradient(
          Gradient(colors: [.white.opacity(alpha), swatch.crest.opacity(alpha * 0.3)]),
          startPoint: CGPoint(x: x - radius, y: y - radius),
          endPoint: CGPoint(x: x + radius, y: y + radius)), lineWidth: 0.65)
      }

      context.stroke(front, with: .linearGradient(
        Gradient(colors: [.white.opacity(0.12), .white.opacity(0.77), swatch.crest.opacity(0.46)]),
        startPoint: .zero, endPoint: CGPoint(x: width, y: 0)),
        style: StrokeStyle(lineWidth: 1, lineCap: .round))

      if splash > 0 {
        let sprayHeight = sin((1 - splash) * .pi) * height * 0.20
        for index in 0..<3 {
          let x = width * (0.32 + Double(index) * 0.18)
          let y = surface(at: x) - sprayHeight * (0.65 + 0.23 * Double(index))
          let radius = width * (0.012 + Double(index % 2) * 0.004)
          context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
            width: 2 * radius, height: 2 * radius)), with: .color(swatch.crest.opacity(splash * 0.9)))
        }
      }
    }
    .allowsHitTesting(false)
  }
}
