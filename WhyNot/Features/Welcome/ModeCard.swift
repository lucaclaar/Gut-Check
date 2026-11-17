import SwiftUI

struct ModeCard: View {
  let title: String
  let subtitle: String
  let mascot: String
  let isReflect: Bool
  var body: some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: 28).fill(isReflect ? GutTheme.indigo : GutTheme.yellow)
        .overlay {
          RoundedRectangle(cornerRadius: 28).strokeBorder(
            isReflect ? Color("GutIndigoBorder") : Color("GutYellowBorder"), lineWidth: 2)
        }
      MascotView(name: mascot, width: isReflect ? 170 : 210, height: isReflect ? 179 : 168)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, isReflect ? 30 : 27).padding(.trailing, isReflect ? 12 : 0)
      VStack(alignment: .leading, spacing: 14) {
        Text(title).font(GutTheme.display(isReflect ? 32 : 26))
        Text(subtitle).font(.system(.subheadline, design: .rounded)).lineSpacing(2)
          .frame(width: 160, alignment: .leading).fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(isReflect ? .white : GutTheme.ink).padding(24)
    }
    .frame(height: 256).accessibilityElement(children: .combine)
  }
}
