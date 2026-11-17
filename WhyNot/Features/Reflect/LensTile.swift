import SwiftUI

struct LensTile: View {
  let lens: ReflectionLens
  let selected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        Text(lens.title).font(GutTheme.display(15)).tracking(-0.45)
          .lineLimit(lens == .worst ? 2 : 1).minimumScaleFactor(0.85)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        Spacer(minLength: 14)
        Text(lens.subtitle).font(.system(.footnote, design: .rounded))
          .fixedSize(horizontal: false, vertical: true).padding(.bottom, 8)
      }
      .padding(.horizontal, 14).padding(.top, 60).padding(.bottom, 20).frame(height: 190)
      .foregroundStyle(GutTheme.ink)
      .background(lens.color.opacity(selected ? 1 : 0.85), in: .rect(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22).strokeBorder(.white, lineWidth: selected ? 2 : 0)
      }
      .overlay(alignment: .top) {
        MascotView(name: lens.mascot, width: 104, height: lens == .best ? 91 : 78)
          .offset(y: lens == .best ? -72 : -58)
      }
      .overlay(alignment: .bottomTrailing) {
        if selected {
          Image(systemName: "checkmark").font(.system(.callout).weight(.bold))
            .foregroundStyle(GutTheme.yellow).frame(width: 24, height: 24)
            .background(GutTheme.ink, in: .circle).padding(10)
        }
      }
      .offset(y: selected ? -16 : 0)
    }
    .buttonStyle(.plain).accessibilityLabel(lens.title)
    .accessibilityValue(selected ? "Selected" : "").accessibilityAddTraits(
      selected ? .isSelected : [])
  }
}
