import SwiftUI

struct ReturnOption: View {
  let title: String
  let subtitle: String
  let symbol: String
  let prominent: Bool
  let action: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    if prominent {
      button
        .buttonStyle(.glassProminent)
        .tint(.white)
        .buttonBorderShape(.roundedRectangle(radius: 22))
    } else {
      button
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 22))
    }
  }

  private var button: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if !typeSize.isAccessibilitySize {
          Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(prominent ? GutTheme.ink : GutTheme.purple)
            .frame(width: 36, height: 36)
            .background(
              prominent ? GutTheme.ink.opacity(0.08) : GutTheme.purple.opacity(0.16), in: .circle)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline)
          Text(subtitle).font(.subheadline)
            .foregroundStyle(prominent ? Color("GutSummaryMuted") : GutTheme.muted)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .accessibilityHidden(true)
      }
      .foregroundStyle(prominent ? GutTheme.ink : .white)
      .padding(.horizontal, 4)
      .padding(.vertical, 10)
      .frame(minHeight: 68)
    }
    .controlSize(.regular)
  }
}
