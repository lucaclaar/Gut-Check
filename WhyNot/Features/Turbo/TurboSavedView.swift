import SwiftUI

struct TurboSavedView: View {
  let session: TurboSession
  let home: () -> Void
  let replay: () -> Void

  private var rating: Double { session.lastSaved?.feeling ?? session.feeling }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        VStack(spacing: 16) {
          MascotView(name: ReflectionSession.feelingMascot(for: rating), width: 180, height: 158)
          Text(rating < 0.66 ? "Pick saved." : "Decision made.")
            .font(GutTheme.display(30))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 8) {
          GutEyebrow(title: "YOU PICKED", color: GutTheme.purple)
          Text(session.lastSaved?.choice ?? session.finalChoice?.text ?? "")
            .font(.system(.title2, design: .rounded).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 15)
        .overlay(alignment: .leading) {
          Capsule().fill(GutTheme.purple).frame(width: 3).accessibilityHidden(true)
        }

        Divider().accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 7) {
          GutEyebrow(title: "FEELING")
          Text(ReflectionSession.feelingTitle(for: rating))
            .font(.system(.headline, design: .rounded))
          if rating < 0.33 {
            Text("It’s okay to still feel unsure.")
              .font(.subheadline).foregroundStyle(GutTheme.muted)
          }
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 38)
      .padding(.bottom, 24).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 12) {
        if rating < 0.33 {
          GutButton(title: "Play another round", prominent: false, action: replay)
        }
        GutButton(title: "Back home", action: home)
      }
      .frame(maxWidth: 500)
      .padding(.horizontal, 24).padding(.bottom, 20)
      .frame(maxWidth: .infinity)
    }
    .background(GutBackground(asset: "32-164-Glow", origin: CGPoint(x: -60, y: 60)))
    .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
  }
}
