import SwiftUI

struct QuestionCard: View {
  let question: ReflectionQuestion
  let number: Int
  @ScaledMetric(relativeTo: .body) private var cardHeight = 357.0
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(number.formatted(.number.precision(.integerLength(2))))
        .font(GutTheme.display(number == 1 ? 68 : 52)).tracking(-1.04)
        .frame(height: 80, alignment: .topLeading)
      Text(question.eyebrow).font(.system(.callout, design: .rounded).weight(.medium))
        .tracking(1.6).padding(.top, 34)
      Text(question.text).font(
        .system(.title2, design: .rounded).weight(.semibold).scaled(by: 1.18)
      )
      .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
      Spacer(minLength: 12)
    }
    .padding(24).frame(maxWidth: .infinity).frame(height: cardHeight, alignment: .topLeading)
    .foregroundStyle(GutTheme.ink).background(question.lens.color, in: .rect(cornerRadius: 28))
    .accessibilityElement(children: .combine)
  }
}
