//
//  WatchLink.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import Foundation
import WatchConnectivity

/// The watch side of the watch <-> iPhone conversation.
final class WatchLink: NSObject, WCSessionDelegate {
  static let shared = WatchLink()  // one single instance for the whole app

  /// Call once when the app starts.
  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  /// Queues a message for the iPhone. Delivered even if the iPhone app is asleep.
  func sendWalkFinished(steps: Int) {
    guard WCSession.default.activationState == .activated else { return }
    WCSession.default.transferUserInfo(["walkSteps": steps])
  }

  // Required by WCSessionDelegate. We don't need to do anything here.
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: (any Error)?
  ) {}
}
