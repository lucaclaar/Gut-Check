import SwiftUI

struct ModeCard: View {
  let title: String
  let subtitle: String
  let mascot: String
  let isReflect: Bool
  @ScaledMetric(relativeTo: .subheadline) private var compactHeight = 196.0
  @Environment(\.dynamicTypeSize) private var typeSize

  private var artwork: some View {
    MascotView(name: mascot, width: isReflect ? 153 : 168, height: isReflect ? 161 : 135)
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: 28).fill(isReflect ? GutTheme.indigo : GutTheme.yellow)
        .overlay {
          RoundedRectangle(cornerRadius: 28).strokeBorder(
            isReflect ? Color("GutIndigoBorder") : Color("GutYellowBorder"), lineWidth: 2)
        }
      if !typeSize.isAccessibilitySize {
        artwork.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(.top, isReflect ? 20 : 30).padding(.trailing, isReflect ? 20 : 10)
      }
      VStack(alignment: .leading, spacing: 7) {
        if typeSize.isAccessibilitySize {
          artwork.frame(maxWidth: .infinity, alignment: .trailing)
        }
        Text(title).font(GutTheme.display(28))
        Text(subtitle).font(.system(.subheadline, design: .rounded)).lineSpacing(2)
          .frame(width: typeSize.isAccessibilitySize ? nil : 152, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(isReflect ? .white : GutTheme.ink).padding(.horizontal, 24)
      .padding(.top, typeSize.isAccessibilitySize ? 20 : 0)
      .padding(.bottom, isReflect ? 30 : 48)
    }
    .frame(height: typeSize.isAccessibilitySize ? nil : compactHeight)
    .accessibilityElement(children: .combine)
  }
}
