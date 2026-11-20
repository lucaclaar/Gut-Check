import SwiftUI

struct ReflectionShuffleView: View {
  let lens: ReflectionLens
  let useStandard: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AccessibilityFocusState private var headingFocused: Bool

  var body: some View {
    GeometryReader { geometry in
      let width = min(260, max(84, min(geometry.size.width - 112, geometry.size.height * 0.42)))
      ScrollView {
        VStack(spacing: 36) {
          TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let slide = reduceMotion ? 0 : pow(sin(time * 2.6), 2)
            ZStack {
              RoundedRectangle(cornerRadius: 28)
                .fill(Color("GutCardBackLight"))
                .rotationEffect(.degrees(-8 - 13 * slide))
                .offset(x: -5 - width * 0.17 * slide, y: 19 - 10 * slide)
              RoundedRectangle(cornerRadius: 28)
                .fill(Color("GutCardBack"))
                .rotationEffect(.degrees(8 + 16 * slide))
                .offset(x: 6 + width * 0.21 * slide, y: 11 - 15 * slide)
              RoundedRectangle(cornerRadius: 28)
                .fill(lens.color)
                .overlay {
                  MascotView(name: lens.mascot, width: width * 0.77, height: width * 0.77)
                }
                .rotationEffect(.degrees(-3 * slide))
                .offset(y: -10 * slide)
            }
            .frame(width: width, height: width * 1.2)
            .accessibilityHidden(true)
          }
          Text("Preparing your cards…")
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($headingFocused)
            .accessibilityIdentifier("reflect.preparingCards")
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }
      .scrollIndicators(.hidden)
    }
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Use standard cards", prominent: false, action: useStandard)
        .padding(.horizontal, 24).padding(.bottom, 20)
    }
    .onAppear { headingFocused = true }
  }
}
