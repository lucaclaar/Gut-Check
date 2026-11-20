import SwiftUI

struct TurboFeelingView: View {
  @Bindable var session: TurboSession
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var shouldReview: Bool { session.feeling < 0.33 && !session.hasReviewedPick }

  var body: some View {
    ScrollView {
      Group {
        if session.reviewingPick { review }
        else { rating }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.vertical, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).background(GutBackground(asset: "32-143-Glow"))
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .bottom) {
      if !session.reviewingPick {
        GutButton(title: shouldReview ? "Revisit my pick" : "Save my decision") {
          if shouldReview { session.reviewPick() } else { session.saveDecision() }
        }
        .accessibilityIdentifier("turbo.save").padding(.horizontal, 24).padding(.bottom, 20)
      }
    }
    .alert("Couldn’t save your decision", item: $session.saveError) { _ in
      Button("Try again", action: session.saveDecision)
      Button("Cancel", role: .cancel) {}
    } message: { error in Text(error) }
  }

  private var rating: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(session.alternativeID == nil
        ? "Your gut picked \(session.chosen?.text ?? "")."
        : "How about \(session.finalChoice?.text ?? "")?")
        .font(GutTheme.display(27)).fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
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
  }

  private var review: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("What did you hope would win?")
        .font(GutTheme.display(27)).accessibilityAddTraits(.isHeader)
      if let suggestion = session.suggestedAlternative {
        Text("You kept \(suggestion.text) in play. How does it feel now?")
          .foregroundStyle(GutTheme.muted)
        GutButton(title: "Consider \(suggestion.text)") { session.chooseAlternative(suggestion.id) }
      }
      ForEach(session.alternatives.filter { $0.id != session.suggestedAlternative?.id }) { option in
        Button {
          session.chooseAlternative(option.id)
        } label: {
          Text(option.text).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glass).controlSize(.large)
      }
      Button("Keep \(session.chosen?.text ?? "my pick")", action: session.keepOriginalPick)
        .buttonStyle(.glass).controlSize(.large)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
