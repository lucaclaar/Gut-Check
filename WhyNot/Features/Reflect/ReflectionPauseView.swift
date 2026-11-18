import SwiftUI

struct ReflectionPauseView: View {
  let session: ReflectionSession
  let lastWatchWalk: WalkExchange.Update?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        MascotView(name: "MascotWorstCase4", width: 250, height: 189)
          .frame(maxWidth: .infinity).padding(.top, 58)
        Text("That's a lot of\nwhat-ifs.").font(GutTheme.display()).padding(.top, 66)
        Text("Moving helps your brain untangle things. Take a 2,000-step walk and come back fresh.").font(.body)
          .foregroundStyle(GutTheme.muted).padding(.top, 40)
        Label("Track with your Apple Watch", systemImage: "applewatch")
          .font(.footnote.weight(.medium))
          .padding(.horizontal, 24).padding(.vertical, 10)
          .background(.white.opacity(0.08), in: .capsule)
          .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }.padding(.top, 64)
        if let lastWatchWalk {
          Text("Last Watch walk · \(lastWatchWalk.steps.formatted()) steps")
            .font(.footnote).foregroundStyle(GutTheme.muted).padding(.top, 10)
        }
      }
      .padding(.horizontal, 24).padding(.bottom, 40)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 14) {
        GutButton(title: "Let's walk", action: session.beginWalk)
          .accessibilityIdentifier("reflect.walk.start")
        GutButton(title: "Keep going anyway", prominent: false, action: session.ready)
      }
      .padding(.horizontal, 24).padding(.bottom, 22)
    }
    .background(GutBackground(asset: "32-94-Glow", origin: CGPoint(x: -80, y: 40)))
    .toolbar(.hidden, for: .navigationBar)
  }
}
