import SwiftUI

struct TipBubble: View {
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text("New here? Tap ? for a quick guide.")
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(GutTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: dismiss) {
        Label("Dismiss tip", systemImage: "xmark")
          .labelStyle(.iconOnly)
          .font(.system(.caption, design: .rounded).weight(.semibold))
          .foregroundStyle(GutTheme.muted)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("home.tip.dismiss")
    }
    .accessibilityIdentifier("home.tip")
  }
}
