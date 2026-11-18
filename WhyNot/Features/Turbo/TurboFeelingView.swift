import SwiftUI

struct TurboFeelingView: View {
  @Bindable var session: TurboSession
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("Your gut picked \(session.chosen?.text ?? "").")
          .font(GutTheme.display(27)).fixedSize(horizontal: false, vertical: true)
        GutEyebrow(title: "HOW DO YOU FEEL ABOUT IT?").padding(.top, 48)
        MascotView(name: session.feelingMascot, width: 184, height: 158)
          .frame(maxWidth: .infinity).padding(.top, 16)
          .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: session.feelingMascot)
        Text(session.feelingTitle).font(GutTheme.display(19))
          .frame(maxWidth: .infinity).padding(.top, 8)
        Slider(value: $session.feeling, in: 0...1).tint(.blue)
          .accessibilityLabel("How do you feel about your decision?").accessibilityValue(session.feelingTitle)
          .frame(height: 52).padding(.top, 16).padding(.horizontal, 16)
        HStack { Text("Bad"); Spacer(); Text("Relieved") }
          .font(.footnote).foregroundStyle(GutTheme.muted).padding(.horizontal, 16)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 40)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).background(GutBackground(asset: "32-143-Glow"))
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Save my decision", action: session.saveDecision)
        .accessibilityIdentifier("turbo.save").padding(.horizontal, 24).padding(.bottom, 20)
    }
    .alert("Couldn’t save your decision", item: $session.saveError) { _ in
      Button("Try again", action: session.saveDecision)
      Button("Cancel", role: .cancel) {}
    } message: { error in Text(error) }
  }
}
