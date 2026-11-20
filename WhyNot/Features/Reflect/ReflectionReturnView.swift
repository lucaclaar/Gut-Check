import SwiftUI

struct ReflectionReturnView: View {
  let session: ReflectionSession

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          VStack(alignment: .leading, spacing: 14) {
            Label("\(session.walkedSteps.formatted()) steps", systemImage: "figure.walk")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(GutTheme.purple)
              .padding(.horizontal, 12)
              .padding(.vertical, 7)
              .background(GutTheme.purple.opacity(0.13), in: .capsule)

            Text("How’s your head?")
              .font(GutTheme.display(29))
              .accessibilityAddTraits(.isHeader)
          }

          MascotView(name: "MascotMixedEmotions1", width: 214, height: 174)
            .frame(maxWidth: .infinity)

          VStack(spacing: 12) {
            ReturnOption(
              title: "Keep reflecting", subtitle: "Revisit your cards",
              symbol: "rectangle.on.rectangle", prominent: false, action: session.keepReflecting)
            ReturnOption(
              title: "I’ve made my decision", subtitle: "Write it down and close it",
              symbol: "checkmark", prominent: true, action: session.ready)
          }
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
    }
    .background(GutBackground(asset: "32-126-Glow"))
    .toolbar(.hidden, for: .navigationBar)
  }
}
