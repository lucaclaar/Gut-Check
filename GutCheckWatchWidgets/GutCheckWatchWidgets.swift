//
//  GutCheckWatchWidgets.swift
//  GutCheckWatchWidgets
//
//  Created by Luca Claar on 24/11/2026.
//

import WidgetKit
import SwiftUI

struct WalkEntry: TimelineEntry {
  let date: Date
}

// The widget is a static shortcut: tapping it opens Gut Check on the Watch.
struct WalkProvider: TimelineProvider {
  func placeholder(in context: Context) -> WalkEntry { WalkEntry(date: .now) }

  func getSnapshot(in context: Context, completion: @escaping (WalkEntry) -> Void) {
    completion(WalkEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WalkEntry>) -> Void) {
    completion(Timeline(entries: [WalkEntry(date: .now)], policy: .never))
  }
}

struct WalkWidgetView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryInline:
      Label("Gut Check walk", systemImage: "figure.walk")
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("Gut Check", systemImage: "figure.walk")
          .font(.system(.headline, design: .rounded))
        Text("Start a walk on your iPhone, then leave it behind.")
          .font(.system(.caption2, design: .rounded))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    default:
      Image(systemName: "figure.walk")
        .font(.system(size: 22, weight: .semibold))
        .widgetAccentable()
    }
  }
}

struct GutCheckWatchWidgets: Widget {
  let kind = "GutCheckWatchWidgets"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WalkProvider()) { _ in
      WalkWidgetView()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Gut Check walk")
    .description("Open Gut Check on your wrist to follow a walk started on your iPhone.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

#Preview(as: .accessoryRectangular) {
  GutCheckWatchWidgets()
} timeline: {
  WalkEntry(date: .now)
}
