import SwiftUI

struct ReflectionPauseView: View {
  let session: ReflectionSession
  let lastWatchWalk: WalkExchange.Update?
  @ScaledMetric(relativeTo: .subheadline) private var watchWordmarkHeight = 16.0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        MascotView(name: "MascotWorstCase4", width: 250, height: 189)
          .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 14) {
          Text("That's a lot of\nwhat-ifs.")
            .font(GutTheme.display())
            .accessibilityAddTraits(.isHeader)

          Text("Moving helps your brain untangle things. Take a 2,000-step walk and come back fresh.")
            .font(.body)
            .foregroundStyle(GutTheme.muted)

          VStack(alignment: .leading, spacing: 8) {
            watchCredit
            if let lastWatchWalk {
              Text("Last Watch walk · \(lastWatchWalk.steps.formatted()) steps")
                .font(.footnote)
                .foregroundStyle(GutTheme.muted)
            }
          }
        }
      }
      .frame(maxWidth: 500)
      .padding(.horizontal, 24)
      .padding(.top, 44)
      .padding(.bottom, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 14) {
        GutButton(title: "Let's walk", action: session.beginWalk)
          .accessibilityIdentifier("reflect.walk.start")
        GutButton(title: "Keep going anyway", prominent: false, action: session.ready)
      }
      .frame(maxWidth: 500)
      .padding(.horizontal, 24)
      .padding(.bottom, 22)
      .frame(maxWidth: .infinity)
    }
    .background(GutBackground(asset: "32-94-Glow", origin: CGPoint(x: -80, y: 40)))
    .toolbar(.hidden, for: .navigationBar)
  }

  private var watchCredit: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 7) {
        watchPrefix
        watchWordmark
      }
      VStack(alignment: .leading, spacing: 6) {
        watchPrefix
        watchWordmark
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Track with your Apple Watch")
  }

  private var watchPrefix: some View {
    Text("Track with your")
      .font(.subheadline)
      .foregroundStyle(GutTheme.muted)
  }

  private var watchWordmark: some View {
    Image(decorative: "AppleWatchWordmark")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: watchWordmarkHeight * (3840.0 / 847.0), height: watchWordmarkHeight)
      .foregroundStyle(.white)
  }
}
