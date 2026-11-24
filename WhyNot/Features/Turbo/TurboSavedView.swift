import SwiftUI

struct TurboSavedView: View {
  let session: TurboSession
  let home: () -> Void
  let replay: () -> Void

  private var record: SavedTurboDecision? { session.lastSaved }
  private var rating: Double? { record?.feeling }
  private var gutPick: String? { record?.gutPick }
  private var needsMoreTime: Bool {
    guard let rating else { return false }
    return rating < 0.33 && gutPick == nil
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        VStack(spacing: 16) {
          MascotView(name: rating.map { ReflectionSession.feelingMascot(for: $0) } ?? "MascotMixedEmotions1",
            width: 180, height: 158)
          Text("Decision made.")
            .font(GutTheme.display(30))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 6) {
          GutEyebrow(title: "YOU DECIDED")
          Text(record?.choice ?? session.finalChoice?.text ?? "")
            .font(GutTheme.display(22))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)
          if let gutPick {
            GutEyebrow(title: "HOW YOU GOT HERE")
            Text("Not great about \(gutPick), so you switched")
              .font(.system(.headline, design: .rounded))
              .padding(.bottom, 12)
          }
          if let rating {
            GutEyebrow(title: "FEELING")
            Text(ReflectionSession.feelingTitle(for: rating))
              .font(.system(.headline, design: .rounded))
          }
          Text("Decided in \((record?.decidedIn ?? session.elapsed).formatted(.number.precision(.fractionLength(1)))) s")
            .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted)
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18)) }
        .accessibilityElement(children: .combine)

        if rating != nil {
          Text(needsMoreTime
            ? "It’s okay to still feel unsure."
            : "Fast choices count too. Your gut had an answer.")
            .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted)
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 38)
      .padding(.bottom, 24).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 12) {
        if needsMoreTime {
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
