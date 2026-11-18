import SwiftUI

struct RecentDecisionRow: View {
  let decision: RecentDecision
  var body: some View {
    HStack(spacing: 12) {
      Circle().fill(Color("GutDecided")).frame(width: 10, height: 10).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(decision.title).font(.system(.subheadline, design: .rounded).weight(.semibold))
          .lineLimit(1)
        Text(
          "Decided · \(ReflectionSession.feelingTitle(for: decision.feeling)) · \(decision.createdAt, format: .relative(presentation: .named))"
        )
        .font(.system(.footnote, design: .rounded)).foregroundStyle(GutTheme.muted).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16).padding(.vertical, 12)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)) }
    .accessibilityElement(children: .combine)
  }
}
