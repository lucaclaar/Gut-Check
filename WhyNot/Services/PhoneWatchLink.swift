import Foundation
import Observation
import WatchConnectivity

@MainActor @Observable
final class PhoneWatchLink: NSObject, WCSessionDelegate {
  static let shared = PhoneWatchLink()

  private(set) var isWatchAppInstalled = false
  private var progress: WalkExchange.Update?
  private var history: [UUID: WalkExchange.Update] = {
    guard let data = UserDefaults.standard.data(forKey: "watchWalkHistory"),
      let records = try? JSONDecoder().decode([UUID: WalkExchange.Update].self, from: data) else { return [:] }
    return records
  }()
  @ObservationIgnored private var phoneState: WalkExchange.PhoneState?
  @ObservationIgnored private var lastSentState: WalkExchange.PhoneState?
  @ObservationIgnored private var activated = false

  var latestStandaloneWalk: WalkExchange.Update? {
    history.values.filter { !$0.linked }.max {
      ($0.finishedAt ?? .distantPast) < ($1.finishedAt ?? .distantPast)
    }
  }

  func update(for id: UUID?) -> WalkExchange.Update? {
    guard let id else { return nil }
    if let finished = history[id] { return finished }
    return progress?.id == id ? progress : nil
  }

  func activate() {
    guard !activated, WCSession.isSupported() else { return }
    activated = true
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func publish(_ state: WalkExchange.PhoneState) {
    phoneState = state
    publishCurrentWalk()
  }

  private func publishCurrentWalk() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    isWatchAppInstalled = session.activationState == .activated
      && session.isPaired && session.isWatchAppInstalled
    guard isWatchAppInstalled, let phoneState, phoneState != lastSentState else { return }
    do {
      var outgoing = phoneState
      outgoing.updatedAt = .now
      let payload = outgoing.payload
      try session.updateApplicationContext(payload)
      lastSentState = phoneState
      if session.isReachable {
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
      }
    } catch {
      // Retry when connectivity changes.
    }
  }

  private func apply(_ update: WalkExchange.Update) {
    let merged = self.update(for: update.id)?.merging(update) ?? update
    if merged.finishedAt != nil {
      guard history[merged.id] != merged else { return }
      history[merged.id] = merged
      if let data = try? JSONEncoder().encode(history) {
        UserDefaults.standard.set(data, forKey: "watchWalkHistory")
      }
    } else if merged.linked, phoneState == nil || phoneState?.request?.id == merged.id {
      progress = merged
    }
  }

  private nonisolated func receive(_ payload: [String: Any]) {
    let update = WalkExchange.Update(payload: payload)
    let legacy = update == nil ? WalkExchange.Completion(payload: payload) : nil
    Task { @MainActor [weak self] in
      guard let self else { return }
      if let update {
        self.apply(update)
      } else if let legacy, let request = self.phoneState?.request, request.id == legacy.id {
        self.apply(.init(request: request, linked: true, steps: legacy.steps, finishedAt: .now))
      }
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receive(applicationContext)
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void) {
    guard message[WalkExchange.requestPhoneStateKey] as? Bool == true else {
      receive(message)
      replyHandler([:])
      return
    }
    replyHandler(session.applicationContext)
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    receive(userInfo)
  }

  nonisolated func session(_ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
    receive(session.receivedApplicationContext)
    Task { @MainActor [weak self] in self?.publishCurrentWalk() }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor [weak self] in self?.publishCurrentWalk() }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor [weak self] in
      self?.lastSentState = nil
      self?.publishCurrentWalk()
    }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    Task { @MainActor [weak self] in
      self?.lastSentState = nil
      self?.isWatchAppInstalled = false
    }
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
