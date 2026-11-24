import ActivityKit
import Foundation
import OSLog
import WidgetKit

@MainActor
final class GutActivityCoordinator {
  private let logger = Logger(subsystem: "GutCheck", category: "Activities")
  private let deviceID = ActivityWidgetStore.readLocal()?.deviceID ?? UUID()
  private let cloud = ActivityWidgetStore.cloud
  private var lastWidgetState: ActivityWidgetStore.LocalState?
  private var lastCloudState: GutActivitySnapshot?
  private var initializedCloud = false
  private var canStart = false
  private var attemptedID: UUID?
  private var desired: GutActivityAttributes.ContentState?
  private var activityTask: Task<Void, Never>?

  func update(_ snapshot: GutActivitySnapshot?, steps: Int? = nil) {
    desired = snapshot.map { .init(snapshot: $0, steps: steps) }
    publishWidgetState()
    reconcileLiveActivity()
  }

  func setForeground(_ active: Bool) {
    canStart = active
    if active { refreshCloud() }
    reconcileLiveActivity()
  }

  func refreshCloud() {
    guard let cloud else { return }
    cloud.synchronize()
    WidgetCenter.shared.reloadTimelines(ofKind: GutActivitySnapshot.widgetKind)
  }

  func remoteActivity(id: UUID) -> GutActivitySnapshot? {
    ActivityWidgetStore.readRemote(excluding: deviceID).first { $0.id == id && .now < $0.expiresAt }
  }

  private func publishWidgetState() {
    guard let cloud else { return }
    let snapshot = desired?.snapshot
    let steps = desired?.steps
    let widgetState = ActivityWidgetStore.LocalState(deviceID: deviceID, activity: snapshot, steps: steps)
    if widgetState != lastWidgetState {
      let shouldReload = widgetState.activity != lastWidgetState?.activity
        || steps.map { $0 / 25 } != (lastWidgetState?.steps).map { $0 / 25 }
      do {
        try ActivityWidgetStore.writeLocal(widgetState)
        lastWidgetState = widgetState
        if shouldReload { WidgetCenter.shared.reloadTimelines(ofKind: GutActivitySnapshot.widgetKind) }
      } catch {
        if lastWidgetState == nil {
          logger.debug("Activity App Group is unavailable: \(error.localizedDescription, privacy: .public)")
        }
      }
    }

    guard !initializedCloud || snapshot != lastCloudState else { return }
    let key = ActivityWidgetStore.cloudPrefix + deviceID.uuidString
    // Keep an independent key per installation. Finishing here cannot hide a different device’s run.
    if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
      cloud.set(data, forKey: key)
    } else {
      cloud.removeObject(forKey: key)
    }
    lastCloudState = snapshot
    initializedCloud = true
  }

  private func reconcileLiveActivity() {
    guard activityTask == nil else { return }
    activityTask = Task {
      defer { activityTask = nil }
      repeat {
        let requested = desired
        let canStart = self.canStart
        await applyLiveActivity(requested, canStart: canStart)
        if requested == desired && canStart == self.canStart { break }
      } while !Task.isCancelled
    }
  }

  private func applyLiveActivity(_ state: GutActivityAttributes.ContentState?, canStart: Bool) async {
    let snapshot = state?.snapshot
    var matching: Activity<GutActivityAttributes>?
    for activity in Activity<GutActivityAttributes>.activities {
      if activity.attributes.id == snapshot?.id, matching == nil, let snapshot, .now < snapshot.expiresAt {
        matching = activity
      } else {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
    guard let snapshot, let state, .now < snapshot.expiresAt else { return }
    let staleDate = snapshot.isWalk ? Date.now.addingTimeInterval(5 * 60) : snapshot.expiresAt
    let content = ActivityContent(state: state, staleDate: staleDate)
    if let matching {
      attemptedID = snapshot.id
      if matching.content.state != state || matching.activityState == .stale {
        await matching.update(content)
      }
    } else if canStart, desired == state, self.canStart, attemptedID != snapshot.id,
      ActivityAuthorizationInfo().areActivitiesEnabled {
      do {
        _ = try Activity.request(attributes: GutActivityAttributes(id: snapshot.id), content: content,
          pushType: nil)
        attemptedID = snapshot.id
      } catch {
        logger.debug("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
