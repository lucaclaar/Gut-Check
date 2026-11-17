import SwiftUI

struct WelcomeView: View {
  let getStarted: () -> Void
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          Spacer(minLength: max(100, proxy.size.height * 0.235))
          MascotView(name: "MascotStillDoubtful2", width: 230, height: 244)
          Text("Gut Check").font(GutTheme.display(50)).tracking(-1)
            .padding(.top, 30).minimumScaleFactor(0.7).lineLimit(1)
          Text("Decide with a little help from your gut.").font(.body)
            .foregroundStyle(GutTheme.muted).padding(.top, 12)
          Spacer(minLength: 100)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollIndicators(.hidden)
      .overlay(alignment: .topLeading) {
        MascotView(name: "MascotMixedEmotions4", width: 241, height: 197)
          .offset(x: -64, y: -7).allowsHitTesting(false)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 18) {
        GutButton(title: "Get started", action: getStarted)
        Text("AN APP BY WHY NOT STUDIO").font(.system(.caption2, design: .rounded).weight(.medium))
          .tracking(1.32).foregroundStyle(Color("GutFooter"))
      }
      .padding(.horizontal, 24).padding(.bottom, 3)
    }
    .background(GutBackground(asset: "32-3-Glow", origin: CGPoint(x: -100, y: 120)))
    .toolbar(.hidden, for: .navigationBar)
  }
}
