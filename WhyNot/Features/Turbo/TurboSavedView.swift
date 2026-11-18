import SwiftUI

struct TurboSavedView: View {
  let session: TurboSession
  let home: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        MascotView(name: "MascotBestCase2", width: 180, height: 158)
          .frame(maxWidth: .infinity).padding(.top, 38)
        Text("Decision made.").font(GutTheme.display(27)).padding(.top, 66)
        VStack(alignment: .leading, spacing: 0) {
          GutEyebrow(title: "YOU DECIDED", color: GutTheme.ink)
          Text(session.lastSaved?.choice ?? session.chosen?.text ?? "")
            .font(.system(.title2, design: .rounded).scaled(by: 1.18))
            .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
          Spacer(minLength: 32)
          GutEyebrow(title: "FEELING", color: GutTheme.ink)
          Text("\(session.feelingTitle) · \(Int(session.elapsed.rounded())) s · \(session.chosen?.rescues ?? 0) \(session.chosen?.rescues == 1 ? "rescue" : "rescues")")
            .font(.callout).padding(.top, 10)
          Text("Fast choices count too. Your gut had an answer.")
            .font(.footnote).foregroundStyle(Color("GutSummaryMuted")).padding(.top, 22)
        }
        .foregroundStyle(GutTheme.ink).padding(24)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(GutTheme.purple, in: .rect(cornerRadius: 28)).padding(.top, 40)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.bottom, 40).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Back home", action: home).padding(.horizontal, 24).padding(.bottom, 20)
    }
    .background(GutBackground(asset: "32-164-Glow", origin: CGPoint(x: -60, y: 60)))
    .toolbar(.hidden, for: .navigationBar).navigationBarBackButtonHidden()
  }
}
