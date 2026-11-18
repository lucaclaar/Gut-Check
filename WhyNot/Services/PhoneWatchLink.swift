//
//  PhoneWatchLink.swift
//  WhyNot
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import Foundation
import Observation
import WatchConnectivity

/// The iPhone side: listens for "walk finished" from the watch.
@Observable
final class PhoneWatchLink: NSObject, WCSessionDelegate {
  static let shared = PhoneWatchLink()

  /// Steps sent by the watch when a walk ends. nil = nothing new.
  var finishedWalkSteps: Int?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// Called by the system when a message from the watch arrives.
  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard let steps = userInfo["walkSteps"] as? Int else { return }
    // Back to the main thread, because the UI reads this value.
    Task { @MainActor in self.finishedWalkSteps = steps }
  }

  // Required on iPhone. Nothing to do in the first two.
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
  ) {}
  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()  // the user switched to another watch: reconnect
  }
}
