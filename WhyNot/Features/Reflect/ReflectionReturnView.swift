import SwiftUI

struct ReflectionReturnView: View {
  let session: ReflectionSession
  @State private var generator = AppleReflectionCardGenerator()

  var body: some View {
    GeometryReader { geometry in
      let topPadding: CGFloat = 36
      let bottomPadding = min(104, max(24, geometry.size.height * 0.13))

      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: 14) {
            Label {
              if session.walkedSteps == 0 {
                Text("No steps recorded")
              } else if session.walkedSteps == 1 {
                Text("1 step")
              } else {
                Text("\(session.walkedSteps.formatted()) steps")
              }
            } icon: {
              Image(systemName: "figure.walk")
            }
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(GutTheme.purple)
              .padding(.horizontal, 12)
              .padding(.vertical, 7)
              .background(GutTheme.purple.opacity(0.13), in: .capsule)

            Text(session.walkedSteps == 0 ? "Ready to keep going?" : "How’s your head?")
              .font(GutTheme.display(29))
              .accessibilityAddTraits(.isHeader)
          }

          Spacer(minLength: 28)

          MascotView(name: "MascotMixedEmotions1", width: 214, height: 174)
            .frame(maxWidth: .infinity)

          Spacer(minLength: 28)

          VStack(spacing: 12) {
            ReturnOption(
              title: "Keep reflecting", subtitle: "Explore new questions",
              symbol: "rectangle.on.rectangle", prominent: false, action: explore)
            ReturnOption(
              title: "I’ve made my decision", subtitle: "Write it down and close it",
              symbol: "checkmark", prominent: true, action: session.ready)
            Button("Sleep on it", action: session.sleepOnIt)
              .font(.subheadline.weight(.semibold))
              .padding(.vertical, 10)
          }
        }
        .frame(maxWidth: 460, minHeight: max(0, geometry.size.height - topPadding - bottomPadding))
        .padding(.horizontal, 24)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
    }
    .background(GutBackground(asset: "32-126-Glow"))
    .toolbar(.hidden, for: .navigationBar)
  }

  private func explore() {
    session.keepReflecting(using: generator.isDeviceAvailable ? generator : nil)
  }
}
