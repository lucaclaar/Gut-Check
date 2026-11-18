import SwiftUI

struct ReflectionCardsView: View {
  let session: ReflectionSession
  @AppStorage("hasDoneCardPractice") private var hasDoneCardPractice = false
  @State private var haptic = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var isPractice: Bool {
    !hasDoneCardPractice && session.index == 0 && session.answers.isEmpty
  }
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack {
          Spacer(minLength: 40)
          if isPractice {
            QuestionDeck(
              question: .practice, number: 0, label: "Try it", answer: finishPractice)
              .frame(maxWidth: min(355, proxy.size.width - 97))
              .accessibilityIdentifier("reflect.practice")
            Text("‹  drag the card  ›").font(.system(.subheadline, design: .rounded))
              .foregroundStyle(GutTheme.muted).padding(.top, 28).accessibilityHidden(true)
          } else {
            QuestionDeck(question: session.currentCard, number: session.index + 1, answer: answer)
              .frame(maxWidth: min(355, proxy.size.width - 97))
          }
          Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollIndicators(.hidden)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 0) {
        if !isPractice {
          HStack(spacing: 6) {
            ForEach(0..<6) { index in
              Circle().fill(index == session.index ? .white : Color("GutDots")).frame(
                width: 6, height: 6)
            }
          }
          .accessibilityLabel("Card \(session.index + 1) of 6").padding(.bottom, 18)
        }
        HStack(spacing: 14) {
          let answerCard = isPractice ? finishPractice : answer
          GutButton(title: "← No", prominent: false) { answerCard(false) }
          GutButton(title: "Yes →", prominent: false) { answerCard(true) }
        }
        if !isPractice {
          GutButton(title: "Ready to make my decision", action: ready).padding(.top, 26)
        }
      }
      .padding(.horizontal, 24).padding(.bottom, 12)
    }
    .navigationTitle(
      isPractice ? "How the cards work" : "\(session.currentCard.lens.title) · \(session.index + 1)/6"
    )
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .background(GutBackground(asset: "32-64-Glow"))
    .sensoryFeedback(.impact(weight: .light), trigger: haptic)
  }
  private func answer(_ yes: Bool) {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { session.answer(yes) }
    haptic += 1
  }
  /// The practice answer is not stored; it only unlocks the real deck.
  private func finishPractice(_: Bool) {
    guard isPractice else { return }
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { hasDoneCardPractice = true }
    haptic += 1
  }
  private func ready() {
    session.ready()
    haptic += 1
  }
}
