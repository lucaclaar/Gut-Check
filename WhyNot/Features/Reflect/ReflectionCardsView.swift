import SwiftUI

struct ReflectionCardsView: View {
  let session: ReflectionSession
  @AppStorage("hasDoneCardPractice") private var hasDoneCardPractice = false
  @State private var haptic = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  private var isPractice: Bool {
    !hasDoneCardPractice && session.index == 0 && session.answers.isEmpty
  }
  var body: some View {
    ZStack {
      cardsContent
        .opacity(session.isPreparingCards ? 0 : 1)
        .allowsHitTesting(!session.isPreparingCards)
        .accessibilityHidden(session.isPreparingCards)
      if session.isPreparingCards {
        ReflectionShuffleView(lens: session.lens, useStandard: session.useStandardCards)
          .transition(.opacity)
      }
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: session.isPreparingCards)
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .background(GutBackground(asset: "32-64-Glow"))
    .sensoryFeedback(.impact(weight: .light), trigger: haptic)
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { session.cancelCardPreparation() }
    }
  }
  private var navigationTitle: String {
    if session.isPreparingCards { return "Reflect" }
    if isPractice { return "How the cards work" }
    return "\(session.currentCard.lens.title) · \(session.index + 1)/\(session.cards.count)"
  }
  private var cardsContent: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack {
          Spacer(minLength: 40)
          if !session.isPreparingCards {
            Group {
              if isPractice {
                QuestionDeck(question: .practice(for: session.lens), number: 0,
                  label: "Try it", answer: finishPractice)
                  .accessibilityIdentifier("reflect.practice")
              } else {
                QuestionDeck(question: session.currentCard, number: session.index + 1, answer: answer)
              }
            }
              .frame(maxWidth: min(355, proxy.size.width - 97))
              .transition(reduceMotion ? .opacity : .opacity.combined(with: .modifier(
                active: ReflectionDeckReveal(angle: -78), identity: ReflectionDeckReveal(angle: 0))))
            if isPractice {
              Text("‹  drag the card  ›").font(.system(.subheadline, design: .rounded))
                .foregroundStyle(GutTheme.muted).padding(.top, 28).accessibilityHidden(true)
            }
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
          if session.usesPersonalizedCards {
            Text("AI-generated cards").font(.caption).foregroundStyle(GutTheme.muted)
              .padding(.bottom, 8)
          }
          HStack(spacing: 6) {
            ForEach(session.cards.indices, id: \.self) { index in
              Circle().fill(index == session.index ? .white : Color("GutDots")).frame(
                width: 6, height: 6)
            }
          }
          .accessibilityLabel("Card \(session.index + 1) of \(session.cards.count)").padding(.bottom, 18)
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

private struct ReflectionDeckReveal: ViewModifier {
  let angle: Double

  func body(content: Content) -> some View {
    content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
  }
}
