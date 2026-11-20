import SwiftUI

struct RecentDecisionRow: View {
  let decision: RecentDecision
  let resume: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  private var isReflect: Bool { decision.mode == .reflect }

  var body: some View {
    HStack(spacing: 12) {
      if !typeSize.isAccessibilitySize {
        Image(systemName: isReflect ? "text.bubble.fill" : "bolt.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(isReflect ? GutTheme.purple : GutTheme.yellow)
          .frame(width: 38, height: 38)
          .background((isReflect ? GutTheme.purple : GutTheme.yellow).opacity(0.13),
            in: .rect(cornerRadius: 11))
          .accessibilityHidden(true)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(decision.title).font(.body.weight(.semibold))
          .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
        Text(isReflect ? "Reflect" : "Turbo")
          .font(.footnote)
          .foregroundStyle(GutTheme.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)

      Button("Resume \(decision.title)", systemImage: "play.fill", action: resume)
        .labelStyle(.iconOnly)
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
    .padding(.vertical, 9)
    .padding(.horizontal, 12)
    .contentShape(.rect)
  }
}
