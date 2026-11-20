import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class ReflectionReminder: NSObject, UNUserNotificationCenterDelegate {
  static let shared = ReflectionReminder()
  private nonisolated static let prefix = "reflect-reminder-"
  @ObservationIgnored private let center = UNUserNotificationCenter.current()
  private(set) var openedID: UUID?

  func activate() { center.delegate = self }

  func scheduleTomorrow(for id: UUID) async throws -> Bool {
    let permission = await center.notificationSettings().authorizationStatus
    switch permission {
    case .notDetermined:
      guard try await center.requestAuthorization(options: [.alert, .sound]) else { return false }
    case .authorized, .provisional, .ephemeral:
      break
    default:
      return false
    }

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

  func isScheduled(for id: UUID) async -> Bool {
    await center.pendingNotificationRequests().contains { $0.identifier == identifier(for: id) }
  }

  func cancel(for id: UUID) {
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
