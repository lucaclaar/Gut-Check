import SwiftUI

struct TipBubble: View {
  let dismiss: () -> Void
  @ScaledMetric(relativeTo: .footnote) private var fontSize = 14.0
  @ScaledMetric(relativeTo: .footnote) private var textWidth = 158.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  var body: some View {
    let bubble = UnevenRoundedRectangle(
      topLeadingRadius: 22, bottomLeadingRadius: 6,
      bottomTrailingRadius: 22, topTrailingRadius: 22)

    Button(action: dismiss) {
      Text("New here? Pick Reflect if you have time, Turbo if you don’t.")
        .font(.system(size: fontSize, weight: .light, design: .rounded))
        .foregroundStyle(GutTheme.ink)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: textWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white, in: bubble)
        .contentShape(bubble)
    }
    .buttonStyle(.plain)
    .accessibilityHint("Dismisses this tip")
    .accessibilityIdentifier("home.tip.dismiss")
    .scaleEffect(appeared || reduceMotion ? 1 : 0.9, anchor: .bottomLeading)
    .opacity(appeared || reduceMotion ? 1 : 0)
    .onAppear {
      withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.14)) {
        appeared = true
      }
    }
  }
}
