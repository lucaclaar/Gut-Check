import SwiftUI
import WidgetKit

struct GutCheckIdleWidgetView: View {
  let family: WidgetFamily

  var body: some View {
    switch family {
    case .accessoryRectangular:
      HStack(spacing: 8) {
        mascot(size: 26)
        VStack(alignment: .leading, spacing: 2) {
          Text("Stuck on something?")
            .font(.system(.headline, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          Text("Tap to decide")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    case .systemMedium:
      HStack(spacing: 12) {
        invitation
        Spacer(minLength: 0)
        mascot(size: 68)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    default:
      VStack(alignment: .leading, spacing: 5) {
        mascot(size: 48)
          .frame(maxWidth: .infinity, alignment: .topTrailing)
        Spacer(minLength: 0)
        invitation
      }
      .foregroundStyle(.white)
    }
  }

  private var invitation: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Stuck on something?")
        .font(GutTheme.display(17))
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .accessibilityAddTraits(.isHeader)
      Text("Tap to decide")
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(GutTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .layoutPriority(1)
  }

  private func mascot(size: CGFloat) -> some View {
    Image(decorative: "DoubtfulMascot")
      .resizable()
      .widgetAccentedRenderingMode(.fullColor)
      .scaledToFit()
      .frame(width: size, height: size)
  }
}
