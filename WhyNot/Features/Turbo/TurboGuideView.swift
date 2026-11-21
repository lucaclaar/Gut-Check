import SwiftUI

/// How to play, shown the first time someone starts a round and from the help button.
struct TurboGuideView: View {
  let seconds: Int
  let buttonTitle: String
  let done: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 8) {
          Text("How to play").font(GutTheme.display(23)).accessibilityAddTraits(.isHeader)
          Text("Every option has its own hidden timer. Some go fast.")
            .font(.system(.subheadline, design: .rounded)).foregroundStyle(GutTheme.muted)
        }
        row(.tap, "Tap to save", "Every tap gives it more time. Tap the ones you want.")
        row(.flick, "Flick to let go", "Throw away the clear no’s.")
        row(.hold, "Hold to pick", "Already sure? Hold it for a moment.")
        row(.clock, "\(seconds) seconds, no extensions", "Taps add time to an option, never to the round.")
      }
      .padding(24).padding(.top, 8)
      .frame(maxWidth: 500, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: buttonTitle, action: done)
        .accessibilityIdentifier("turbo.guide.done")
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: 500)
    }
    .presentationDetents([.height(500), .large])
    .presentationDragIndicator(.visible)
  }

  private func row(_ icon: TurboGuideIcon.Kind, _ title: String, _ detail: String) -> some View {
    HStack(spacing: 16) {
      TurboGuideIcon(kind: icon)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(.body, design: .rounded).weight(.semibold))
        Text(detail).font(.system(.subheadline, design: .rounded)).foregroundStyle(GutTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// The how-to icons from the Turbo design: a gold bubble with a gesture cue.
struct TurboGuideIcon: View {
  enum Kind { case tap, flick, hold, clock }
  let kind: Kind

  private let gold = GutTheme.yellow

  var body: some View {
    ZStack {
      switch kind {
      case .tap:
        Circle().stroke(GutTheme.orange, lineWidth: 2).frame(width: 46, height: 46)
        bubble(36)
      case .flick:
        VStack(alignment: .leading, spacing: 4) {
          ForEach([14.0, 11, 8], id: \.self) { width in
            Capsule().fill(.white.opacity(0.7)).frame(width: width, height: 3)
          }
        }
        .offset(x: -15)
        bubble(30).offset(x: 9)
      case .hold:
        Circle().fill(.white).frame(width: 46, height: 46)
        bubble(36)
      case .clock:
        bubble(36)
        Path { path in
          path.move(to: CGPoint(x: 24, y: 15))
          path.addLine(to: CGPoint(x: 24, y: 25))
          path.addLine(to: CGPoint(x: 30, y: 29))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        .frame(width: 48, height: 48)
      }
    }
    .frame(width: 48, height: 48)
    .accessibilityHidden(true)
  }

  private func bubble(_ size: Double) -> some View {
    Circle().fill(gold.opacity(0.35)).overlay { Circle().stroke(gold, lineWidth: 2) }
      .frame(width: size, height: size)
  }
}

#Preview {
  Color.clear.sheet(isPresented: .constant(true)) {
    TurboGuideView(seconds: 15, buttonTitle: "Got it, start") {}
  }
}
