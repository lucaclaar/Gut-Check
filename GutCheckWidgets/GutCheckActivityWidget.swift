import SwiftUI
import WidgetKit

private struct ActivityEntry: TimelineEntry {
  let date: Date
  var activity: GutActivitySnapshot?
  var steps: Int?
  var fromAnotherDevice = false
}

private struct GutCheckActivityProvider: TimelineProvider {
  func placeholder(in context: Context) -> ActivityEntry {
    ActivityEntry(date: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (ActivityEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entries().first ?? ActivityEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityEntry>) -> Void) {
    ActivityWidgetStore.cloud?.synchronize()
    let entries = entries()
    completion(Timeline(entries: entries, policy: .after(.now + 15 * 60)))
  }

  private func entries() -> [ActivityEntry] {
    let local = ActivityWidgetStore.readLocal()
    let remote = ActivityWidgetStore.readRemote(excluding: local?.deviceID)
    let now = Date.now
    // Schedule known expirations even when the app is suspended or offline.
    let expirations = Set(([local?.activity].compactMap { $0 } + remote).map(\.expiresAt))
    let dates = [now] + expirations.filter { $0 > now && $0 <= now + 15 * 60 }.sorted()
    return dates.map { date in
      let activity = GutActivitySnapshot.current(local: local?.activity, remote: remote, at: date)
      let isLocal = activity != nil && activity?.id == local?.activity?.id
      return ActivityEntry(date: date, activity: activity, steps: isLocal ? local?.steps : nil,
        fromAnotherDevice: activity != nil && !isLocal)
    }
  }
}

struct GutCheckActivityWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: GutActivitySnapshot.widgetKind, provider: GutCheckActivityProvider()) { entry in
      GutCheckActivityWidgetView(entry: entry)
        .widgetURL(entry.activity?.url ?? GutActivitySnapshot.homeURL)
    }
    .configurationDisplayName("Gut Check Activity")
    .description("See a Reflect walk or Turbo round at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

private struct GutCheckActivityWidgetView: View {
  let entry: ActivityEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      if let activity = entry.activity {
        activityContent(activity)
      } else {
        GutCheckIdleWidgetView(family: family)
      }
    }
    .containerBackground(for: .widget) {
      GutTheme.background.overlay {
        if let activity = entry.activity {
          RadialGradient(colors: [activity.tint.opacity(0.25), .clear],
            center: .topTrailing, startRadius: 8, endRadius: 140)
        } else {
          RadialGradient(colors: [GutTheme.indigo.opacity(0.65), GutTheme.indigo.opacity(0.18), .clear],
            center: UnitPoint(x: 0.67, y: 0.73), startRadius: 0, endRadius: 100)
        }
      }
    }
  }

  @ViewBuilder private func activityContent(_ activity: GutActivitySnapshot) -> some View {
    if family == .accessoryRectangular {
      HStack(spacing: 8) {
        if activity.isWalk {
          GutActivityIcon(snapshot: activity, steps: entry.steps, diameter: 26, showsProgress: false)
            .accessibilityHidden(true)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(activity.title).font(.headline).widgetAccentable()
          GutActivityMetric(snapshot: activity, steps: entry.steps, compact: true)
            .privacySensitive(activity.isWalk && entry.steps != nil)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          if family == .systemSmall {
            icon(for: activity, diameter: 38)
            Spacer(minLength: 2)
          }
          Text(activity.title)
            .font(GutTheme.display(15)).minimumScaleFactor(0.75).accessibilityAddTraits(.isHeader)
          GutActivityMetric(snapshot: activity, steps: entry.steps)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .privacySensitive(activity.isWalk && entry.steps != nil)
          Text(entry.fromAnotherDevice ? "On another device" : activity.status)
            .font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
        }
        if family == .systemMedium {
          Spacer(minLength: 0)
          icon(for: activity, diameter: 58).frame(width: 72)
        }
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }

  private func icon(for activity: GutActivitySnapshot, diameter: CGFloat) -> some View {
    GutActivityIcon(snapshot: activity, steps: entry.steps, diameter: diameter)
      .widgetAccentable()
      .accessibilityHidden(true)
  }
}
