import SwiftUI

struct GutButton: View {
  let title: String
  var prominent = true
  let action: () -> Void

  var body: some View {
    if prominent {
      Button(action: action) {
        Text(title).font(.system(.body, design: .rounded).weight(.semibold))
          .foregroundStyle(GutTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 20)
      }
      .buttonStyle(.glassProminent).tint(.white)
      .controlSize(.large).buttonBorderShape(.capsule)
    } else {
      Button(action: action) {
        Text(title).font(.system(.body, design: .rounded).weight(.semibold))
          .frame(maxWidth: .infinity, minHeight: 20)
      }
      .buttonStyle(.glass).controlSize(.large).buttonBorderShape(.capsule)
    }
  }
}
