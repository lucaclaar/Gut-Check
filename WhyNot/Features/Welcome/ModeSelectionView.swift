import SwiftUI

struct ModeSelectionView: View {
  let session: ReflectionSession
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("How do you want\nto decide?").font(GutTheme.display(28))
          .fixedSize(horizontal: false, vertical: true).padding(.bottom, 58)
        Button(action: session.start) {
          ModeCard(
            title: "Reflect",
            subtitle: "When you don't have all the options and need time to think.",
            mascot: "MascotStillDoubtful1", isReflect: true)
        }
        .buttonStyle(.plain).accessibilityIdentifier("mode.reflect")
        ModeCard(
          title: "Turbo", subtitle: "Few options to make a quick decision.",
          mascot: "MascotWorstCase3", isReflect: false
        )
        .accessibilityLabel("Turbo, coming soon").padding(.top, 16)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 46).padding(.bottom, 50)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).background(GutBackground()).toolbar(.hidden, for: .navigationBar)
  }
}
