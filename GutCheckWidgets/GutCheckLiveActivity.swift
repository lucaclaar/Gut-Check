import ActivityKit
import SwiftUI
import WidgetKit

struct GutCheckLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: GutActivityAttributes.self) { context in
      GutCheckLiveCard(context: context)
        .activityBackgroundTint(GutTheme.background)
        .activitySystemActionForegroundColor(.white)
        .widgetURL(context.state.snapshot.url)
    } dynamicIsland: { context in
      let snapshot = context.state.snapshot
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          activityIcon(context, diameter: 34)
        }
        DynamicIslandExpandedRegion(.trailing) {
          metric(context).font(.system(.headline, design: .rounded)).foregroundStyle(snapshot.tint)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 5) {
            Text(snapshot.title).font(GutTheme.display(15))
            Text(context.isStale ? "Open Gut Check to update" : snapshot.status)
              .font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        activityIcon(context, diameter: 24)
      } compactTrailing: {
        metric(context, compact: true)
          .font(.system(.caption, design: .rounded, weight: .semibold))
          .frame(width: 43)
      } minimal: {
        activityIcon(context, diameter: 24)
      }
      .widgetURL(snapshot.url)
      .keylineTint(snapshot.tint)
    }
    .supplementalActivityFamilies([.small])
  }

  private func activityIcon(_ context: ActivityViewContext<GutActivityAttributes>, diameter: CGFloat) -> some View {
    let snapshot = context.state.snapshot
    return GutActivityIcon(snapshot: snapshot, steps: context.state.steps, diameter: diameter,
      showsProgress: diameter > 24)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(snapshot.title)
  }

  private func metric(_ context: ActivityViewContext<GutActivityAttributes>, compact: Bool = false) -> some View {
    GutActivityMetric(snapshot: context.state.snapshot, steps: context.state.steps, compact: compact)
      .privacySensitive(context.state.snapshot.isWalk && context.state.steps != nil)
  }
}

private struct GutCheckLiveCard: View {
  let context: ActivityViewContext<GutActivityAttributes>
  @Environment(\.activityFamily) private var family

  var body: some View {
    let snapshot = context.state.snapshot
    HStack(spacing: 12) {
      GutActivityIcon(snapshot: snapshot, steps: context.state.steps, diameter: family == .small ? 26 : 46,
        showsProgress: family != .small)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(snapshot.title).font(family == .small ? .headline : GutTheme.display(15))
        Text(context.isStale ? "Open Gut Check to update" : snapshot.status)
          .font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
      }
      Spacer(minLength: 4)
      GutActivityMetric(snapshot: snapshot, steps: context.state.steps, compact: family == .small)
        .font(.system(family == .small ? .headline : .title2, design: .rounded, weight: .semibold))
        .privacySensitive(snapshot.isWalk && context.state.steps != nil)
    }
    .foregroundStyle(.white)
    .padding(family == .small ? 10 : 16)
  }
}
