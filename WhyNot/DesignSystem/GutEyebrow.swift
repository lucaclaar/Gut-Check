import SwiftUI

struct GutEyebrow: View {
  let title: String
  var color: Color = GutTheme.muted
  var body: some View {
    Text(title).font(.system(.caption, design: .rounded).weight(.medium))
      .tracking(1.44).foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
