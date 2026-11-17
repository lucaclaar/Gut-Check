import SwiftUI

struct ReturnOption: View {
  let title: String
  let subtitle: String
  let prominent: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text(title).font(.title2)
          Text(subtitle).font(.subheadline)
            .foregroundStyle(prominent ? Color("GutSummaryMuted") : GutTheme.muted)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.right").font(.title2)
      }
      .foregroundStyle(prominent ? GutTheme.ink : .white).padding(24)
      .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
      .background(prominent ? .white : .white.opacity(0.08), in: .rect(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(prominent ? 0 : 0.18))
      }
    }
    .buttonStyle(.plain)
  }
}
