import SwiftUI

struct QuestionDeck: View {
  let question: ReflectionQuestion
  let number: Int
  let answer: (Bool) -> Void
  @State private var translation = CGSize.zero
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(spacing: -32) {
      MascotView(name: question.mascot, width: 140, height: 107)
        .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, -22)
      QuestionCard(question: question, number: number)
        .overlay(alignment: .topTrailing) {
          if abs(translation.width) > 30 {
            Text(translation.width > 0 ? "YES" : "NO").font(GutTheme.display(22)).padding(12)
              .overlay { RoundedRectangle(cornerRadius: 16).stroke(lineWidth: 2) }
              .padding(20).foregroundStyle(GutTheme.ink)
          }
        }
        .offset(translation).rotationEffect(.degrees(reduceMotion ? 0 : translation.width / 24))
        .gesture(
          DragGesture(minimumDistance: 16).onChanged { translation = $0.translation }.onEnded(
            finishDrag)
        )
        .background {
          RoundedRectangle(cornerRadius: 28).fill(Color("GutCardBackLight"))
            .padding(.horizontal, 14).offset(y: 20)
          RoundedRectangle(cornerRadius: 28).fill(Color("GutCardBack"))
            .padding(.horizontal, 7).offset(y: 10)
        }
        .accessibilityAction(named: "Answer yes") { answer(true) }
        .accessibilityAction(named: "Answer no") { answer(false) }
    }
    .onChange(of: question.id) { translation = .zero }
  }
  private func finishDrag(_ value: DragGesture.Value) {
    if abs(value.translation.width) > 85 || abs(value.predictedEndTranslation.width) > 180 {
      answer(value.translation.width > 0)
      translation = .zero
    } else {
      withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { translation = .zero }
    }
  }
}
