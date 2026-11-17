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
      MascotView(name: mascot, width: isReflect ? 153 : 168, height: isReflect ? 161 : 135)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, isReflect ? 20 : 30).padding(.trailing, isReflect ? 20 : 10)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(GutTheme.display(28))
        Text(subtitle).font(.system(.subheadline, design: .rounded)).lineSpacing(2)
          .frame(width: 152, alignment: .leading).fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(isReflect ? .white : GutTheme.ink).padding(.horizontal, 24)
      .padding(.bottom, isReflect ? 30 : 48)
    }
    .frame(height: 196).accessibilityElement(children: .combine)
  }
}
