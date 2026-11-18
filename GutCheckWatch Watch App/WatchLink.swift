//
//  WatchLink.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import Foundation
import Observation
import UserNotifications
import WatchConnectivity
import WatchKit

@MainActor @Observable
final class WatchLink: NSObject, WCSessionDelegate {
  static let shared = WatchLink()

  private(set) var localWalk: WalkExchange.Update? = {
    guard let data = UserDefaults.standard.data(forKey: "localWalk") else { return nil }
    return try? JSONDecoder().decode(WalkExchange.Update.self, from: data)
  }()
  private var phoneState = WalkExchange.PhoneState()
  @ObservationIgnored private var notifications = UNUserNotificationCenter.current()
  @ObservationIgnored private var activated = false
  @ObservationIgnored private var pending: [WalkExchange.Update] = {
    guard let data = UserDefaults.standard.data(forKey: "pendingWalks") else { return [] }
    return (try? JSONDecoder().decode([WalkExchange.Update].self, from: data)) ?? []
  }()
  @ObservationIgnored private var finishedLinkedID = UserDefaults.standard.string(forKey: "finishedLinkedWalk")
  @ObservationIgnored private var seenInvitationID = UserDefaults.standard.string(forKey: "seenWalkInvitation")
  @ObservationIgnored private var showingInvitation = false
  @ObservationIgnored private var lastSentWalk: WalkExchange.Update?
  @ObservationIgnored private var lastLiveProgressAt = Date.distantPast
  private let notificationID = "reflect-walk-ready"

  var availableWalk: WalkExchange.Request? {
    guard let request = phoneState.request, request.id.uuidString != finishedLinkedID else { return nil }
    return request
  }

  var displayedSteps: Int {
    guard let localWalk else { return 0 }
    let phoneSteps = localWalk.linked && phoneState.request?.id == localWalk.id ? phoneState.steps : 0
    return max(localWalk.steps, phoneSteps)
  }

  func activate() {
    guard !activated, WCSession.isSupported() else { return }
    activated = true
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func foreground() async {
    activate()
    if await notifications.notificationSettings().authorizationStatus == .notDetermined {
      _ = try? await notifications.requestAuthorization(options: [.alert, .sound])
    }
    await refresh()
    requestPhoneState()
  }

  func handleBackgroundConnectivity() async {
    activate()
    let session = WCSession.default
    for _ in 0..<15 {
      if session.activationState == .activated && !session.hasContentPending && !showingInvitation { break }
      do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
    }
    await refresh()
  }

  func startWalk() {
    let invitation = availableWalk
    let walk = WalkExchange.Update(request: invitation ?? .init(), linked: invitation != nil)
    store(walk)
    clearAlert()
    publishWalk()
  }

  func recordSteps(_ steps: Int) {
    guard var walk = localWalk, walk.finishedAt == nil, steps > walk.steps else { return }
    walk.steps = steps
    store(walk)
    if displayedSteps >= WalkExchange.goal {
      finishWalk()
    } else {
      publishWalk()
    }
  }

  func finishWalk() {
    guard var walk = localWalk, walk.finishedAt == nil else { return }
    walk.steps = displayedSteps
    walk.finishedAt = .now
    pending.append(walk)
    savePending()
    storeFinished(walk)
    publishWalk()
    flushCompletedWalks()
    WKInterfaceDevice.current().play(.success)
  }

  func dismissSummary() { store(nil) }

  private func refresh() async {
    await applyPhoneState(WalkExchange.PhoneState(payload: WCSession.default.receivedApplicationContext))
  }

  private func applyPhoneState(_ state: WalkExchange.PhoneState) async {
    if let previous = phoneState.updatedAt, (state.updatedAt ?? .distantPast) < previous { return }
    if let request = state.request, request.id == phoneState.request?.id {
      phoneState.steps = max(phoneState.steps, state.steps)
      phoneState.completion = state.completion
      phoneState.updatedAt = state.updatedAt
    } else {
      phoneState = state
    }

    if let completion = state.completion, var walk = localWalk,
      walk.linked, walk.id == completion.id, walk.finishedAt == nil {
      walk.steps = max(walk.steps, completion.steps)
      walk.finishedAt = .now
      storeFinished(walk)
    }
    publishWalk()
    flushCompletedWalks()
    if let invitation = availableWalk, let walk = localWalk,
      walk.finishedAt != nil, invitation.id != walk.id {
      dismissSummary()
    }
    await updateInvitation()
  }

  private func requestPhoneState() {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else { return }
    session.sendMessage([WalkExchange.requestPhoneStateKey: true], replyHandler: { [weak self] payload in
      self?.receivePhoneState(payload)
    }, errorHandler: nil)
  }

  private func storeFinished(_ walk: WalkExchange.Update) {
    if walk.linked {
      finishedLinkedID = walk.id.uuidString
      UserDefaults.standard.set(finishedLinkedID, forKey: "finishedLinkedWalk")
    }
    store(walk)
    clearAlert()
  }

  private func store(_ walk: WalkExchange.Update?) {
    localWalk = walk
    UserDefaults.standard.set(walk.flatMap { try? JSONEncoder().encode($0) }, forKey: "localWalk")
  }

  private func savePending() {
    if let data = try? JSONEncoder().encode(pending) {
      UserDefaults.standard.set(data, forKey: "pendingWalks")
    }
  }

  private func publishWalk() {
    guard let walk = localWalk, (walk.linked || walk.finishedAt != nil),
      walk != lastSentWalk, WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isCompanionAppInstalled else { return }
    do {
      try session.updateApplicationContext(walk.payload)
      if session.isReachable, lastSentWalk?.id != walk.id || walk.finishedAt != nil
        || Date.now.timeIntervalSince(lastLiveProgressAt) >= 2 {
        lastLiveProgressAt = .now
        session.sendMessage(walk.payload, replyHandler: nil, errorHandler: nil)
      }
      lastSentWalk = walk
    } catch {
      // Activation, reachability and foreground transitions retry the latest progress.
    }
  }

  private func flushCompletedWalks() {
    guard !pending.isEmpty, WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isCompanionAppInstalled else { return }
    #if targetEnvironment(simulator)
      guard session.isReachable else { return }
      for walk in pending { session.sendMessage(walk.payload, replyHandler: nil, errorHandler: nil) }
      pending.removeAll()
      savePending()
    #else
      let queued = Set(session.outstandingUserInfoTransfers.compactMap {
        WalkExchange.Update(payload: $0.userInfo)?.id
      })
      for walk in pending where !queued.contains(walk.id) {
        session.transferUserInfo(walk.payload)
      }
    #endif
  }

  private func updateInvitation() async {
    guard let request = availableWalk, localWalk?.finishedAt != nil || localWalk == nil else {
      clearAlert()
      return
    }
    if WKApplication.shared().applicationState == .active {
      rememberInvitation(request.id)
      clearAlert()
      return
    }
    guard !showingInvitation, request.id.uuidString != seenInvitationID,
      Date.now.timeIntervalSince(request.startedAt) < 15 * 60 else { return }
    showingInvitation = true
    defer { showingInvitation = false }

    let permission = await notifications.notificationSettings().authorizationStatus
    guard permission == .authorized || permission == .provisional,
      availableWalk?.id == request.id, WKApplication.shared().applicationState != .active else { return }
    let content = UNMutableNotificationContent()
    content.title = "Your Reflect walk is ready"
    content.body = "Open Gut Check to track your steps on Apple Watch."
    content.sound = .default
    do {
      try await notifications.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: nil))
      rememberInvitation(request.id)
    } catch {
      // The linked walk is still available on the Watch start screen.
    }
  }

  private func rememberInvitation(_ id: UUID) {
    seenInvitationID = id.uuidString
    UserDefaults.standard.set(seenInvitationID, forKey: "seenWalkInvitation")
  }

  private func clearAlert() {
    notifications.removePendingNotificationRequests(withIdentifiers: [notificationID])
    notifications.removeDeliveredNotifications(withIdentifiers: [notificationID])
  }

  private nonisolated func receivePhoneState(_ payload: [String: Any]) {
    let state = WalkExchange.PhoneState(payload: payload)
    Task { @MainActor [weak self] in await self?.applyPhoneState(state) }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receivePhoneState(applicationContext)
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receivePhoneState(message)
  }

  nonisolated func session(_ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
    Task { @MainActor [weak self] in await self?.refresh() }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor [weak self] in
      await self?.refresh()
      self?.requestPhoneState()
    }
  }

  nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
    Task { @MainActor [weak self] in
      self?.lastSentWalk = nil
      await self?.refresh()
    }
  }

  nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer,
    error: (any Error)?) {
    guard error == nil, let id = WalkExchange.Update(payload: userInfoTransfer.userInfo)?.id else { return }
    Task { @MainActor [weak self] in
      self?.pending.removeAll { $0.id == id }
      self?.savePending()
    }
  }
}
