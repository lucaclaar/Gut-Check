import SwiftUI

struct ReflectionReturnView: View {
  let session: ReflectionSession
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(session.walkedSteps.formatted()) steps.\nHow's your head?").font(
          GutTheme.display(28)
        ).padding(.top, 46)
        MascotView(name: "MascotMixedEmotions1", width: 270, height: 211)
          .frame(maxWidth: .infinity).padding(.top, 78)
        ReturnOption(
          title: "Keep reflecting", subtitle: "Shuffle more what-if cards", prominent: false,
          action: session.keepReflecting
        ).padding(.top, 68)
        ReturnOption(
          title: "I've made my decision", subtitle: "Write it down and close it", prominent: true,
          action: session.ready
        ).padding(.top, 16)
      }
      .padding(.horizontal, 24).padding(.bottom, 40)
    }
    .scrollIndicators(.hidden).background(GutBackground(asset: "32-126-Glow"))
    .toolbar(.hidden, for: .navigationBar)
  }
}
