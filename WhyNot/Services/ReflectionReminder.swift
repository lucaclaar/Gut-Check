import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class ReflectionReminder: NSObject, UNUserNotificationCenterDelegate {
  enum Status: Equatable {
    case scheduling
    case scheduled
    case notificationsDisabled
    case failed

    var message: String {
      switch self {
      case .scheduling: "Setting your reminder…"
      case .scheduled: "We’ll remind you tomorrow at 9:00 AM."
      case .notificationsDisabled: "Turn on notifications for Gut Check in Settings to receive reminders."
      case .failed: "We couldn’t set your reminder."
      }
    }
  }

  private struct SchedulingOperation {
    let token: UUID
    let task: Task<Void, Never>
  }

  static let shared = ReflectionReminder()
  private nonisolated static let prefix = "reflect-reminder-"
  @ObservationIgnored private let center = UNUserNotificationCenter.current()
  @ObservationIgnored private var operations: [UUID: SchedulingOperation] = [:]
  private(set) var openedID: UUID?
  private(set) var statuses: [UUID: Status] = [:]

  func activate() { center.delegate = self }

  func update(for decision: SavedDecision) {
    let id = decision.id
    let previous = operations[id]?.task
    cancel(for: id)
    guard decision.isDeferred == true || decision.feeling < 0.33 else { return }

    statuses[id] = .scheduling
    let token = UUID()
    let task = Task {
      // Let a cancelled operation finish removing its request before reusing the same identifier.
      await previous?.value
      defer {
        if operations[id]?.token == token { operations[id] = nil }
      }
      guard !Task.isCancelled else { return }

      do {
        let scheduled = try await scheduleTomorrow(for: id)
        if Task.isCancelled {
          if scheduled { removeNotifications(for: id) }
          return
        }
        statuses[id] = scheduled ? .scheduled : .notificationsDisabled
      } catch {
        if !Task.isCancelled { statuses[id] = .failed }
      }
    }
    operations[id] = SchedulingOperation(token: token, task: task)
  }

  private func scheduleTomorrow(for id: UUID) async throws -> Bool {
    let permission = await center.notificationSettings().authorizationStatus
    try Task.checkCancellation()
    switch permission {
    case .notDetermined:
      guard try await center.requestAuthorization(options: [.alert, .sound]) else { return false }
    case .authorized, .provisional, .ephemeral:
      break
    default:
      return false
    }

    try Task.checkCancellation()
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now.addingTimeInterval(86_400)
    var time = calendar.dateComponents([.year, .month, .day], from: tomorrow)
    time.hour = 9
    time.minute = 0

    let content = UNMutableNotificationContent()
    content.title = "Ready to revisit your decision?"
    content.body = "Pick up where you left off in Reflect."
    content.sound = .default
    let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: false)
    try await center.add(.init(identifier: identifier(for: id), content: content, trigger: trigger))
    return true
  }

  func cancel(for id: UUID) {
    operations[id]?.task.cancel()
    statuses[id] = nil
    removeNotifications(for: id)
  }

  private func removeNotifications(for id: UUID) {
    let identifier = identifier(for: id)
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
    center.removeDeliveredNotifications(withIdentifiers: [identifier])
  }

  func clearOpenedID() { openedID = nil }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse) async {
    let identifier = response.notification.request.identifier
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
      identifier.hasPrefix(Self.prefix),
      let id = UUID(uuidString: String(identifier.dropFirst(Self.prefix.count))) else { return }
    await MainActor.run { openedID = id }
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  private func identifier(for id: UUID) -> String { Self.prefix + id.uuidString }
}
