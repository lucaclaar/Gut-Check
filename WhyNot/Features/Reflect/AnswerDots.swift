import SwiftUI

struct AnswerDots: View {
  let answers: [ReflectionAnswer]
  var body: some View {
    HStack(spacing: 4) {
      ForEach(answers) { answer in
        Circle().fill(answer.yes ? answer.question.lens.color : .clear)
          .overlay { Circle().strokeBorder(answer.question.lens.color) }.frame(width: 8, height: 8)
      }
    }
    .accessibilityHidden(true)
  }
}
