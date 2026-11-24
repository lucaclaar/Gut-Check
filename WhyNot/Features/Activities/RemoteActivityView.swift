import SwiftUI

struct RemoteActivityView: View {
  let activity: GutActivitySnapshot
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      TimelineView(.explicit([.now, activity.expiresAt])) { context in
        VStack(alignment: .leading, spacing: 16) {
          Label("On another device", systemImage: activity.symbol)
            .font(.subheadline.weight(.semibold)).foregroundStyle(activity.tint)
          Text(activity.title).font(GutTheme.display()).accessibilityAddTraits(.isHeader)
          if context.date < activity.expiresAt {
            GutActivityMetric(snapshot: activity).font(.system(.title2, design: .rounded, weight: .semibold))
            Text(activity.status).foregroundStyle(GutTheme.muted)
          } else {
            Text("No active session").foregroundStyle(GutTheme.muted)
          }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .background(GutBackground())
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
