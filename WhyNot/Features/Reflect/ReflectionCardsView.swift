import SwiftUI

struct ReflectionCardsView: View {
  let session: ReflectionSession
  @State private var haptic = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack {
          Spacer(minLength: 40)
          QuestionDeck(question: session.currentCard, number: session.index + 1, answer: answer)
            .frame(maxWidth: min(355, proxy.size.width - 97))
          Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollIndicators(.hidden)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 0) {
        HStack(spacing: 6) {
          ForEach(0..<6) { index in
            Circle().fill(index == session.index ? .white : Color("GutDots")).frame(
              width: 6, height: 6)
          }
        }
        .accessibilityLabel("Card \(session.index + 1) of 6").padding(.bottom, 18)
        HStack(spacing: 14) {
          GutButton(title: "← No", prominent: false) { answer(false) }
          GutButton(title: "Yes →", prominent: false) { answer(true) }
        }
        GutButton(title: "Ready to make my decision", action: ready).padding(.top, 26)
      }
      .padding(.horizontal, 24).padding(.bottom, 12)
    }
    .navigationTitle("\(session.currentCard.lens.title) · \(session.index + 1)/6")
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .background(GutBackground(asset: "32-64-Glow"))
    .sensoryFeedback(.impact(weight: .light), trigger: haptic)
  }
  private func answer(_ yes: Bool) {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { session.answer(yes) }
    haptic += 1
  }
  private func ready() {
    session.ready()
    haptic += 1
  }
}
