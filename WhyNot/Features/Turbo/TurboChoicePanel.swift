import SwiftUI

/// The bottom panel used when someone isn't ready to decide: the paused round
/// and leaving the options screen. Prominent first, then glass, then destructive.
struct TurboChoicePanel: View {
  struct Action: Identifiable {
    enum Kind { case prominent, glass, destructive, plain }
    let title: String
    var kind: Kind = .glass
    let perform: () -> Void
    var id: String { title }
  }

  let title: String
  let message: String
  let actions: [Action]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(GutTheme.display(20)).accessibilityAddTraits(.isHeader)
      Text(message)
        .font(.system(.subheadline, design: .rounded)).foregroundStyle(GutTheme.muted)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
      ForEach(actions) { action in
        switch action.kind {
        case .prominent: GutButton(title: action.title, action: action.perform)
        case .glass: GutButton(title: action.title, prominent: false, action: action.perform)
        case .destructive, .plain:
          Button(action: action.perform) {
            Text(action.title).font(.system(.body, design: .rounded).weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .foregroundStyle(action.kind == .destructive ? TurboPalette.dangerText : GutTheme.muted)
        }
      }
    }
    .padding(24)
    .frame(maxWidth: 500)
  }
}
