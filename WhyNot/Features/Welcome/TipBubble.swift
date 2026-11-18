import SwiftUI

struct TipBubble: View {
  let text: String
  let dismiss: () -> Void

  var body: some View {
    Button(action: dismiss) {
      Text(text).font(.system(.subheadline, design: .rounded).weight(.medium))
        .foregroundStyle(GutTheme.ink).multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
          .white,
          in: UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 6, bottomTrailingRadius: 22,
            topTrailingRadius: 22))
    }
    .buttonStyle(.plain)
    .accessibilityHint("Dismisses this tip")
    .accessibilityIdentifier("home.tip")
  }
}
