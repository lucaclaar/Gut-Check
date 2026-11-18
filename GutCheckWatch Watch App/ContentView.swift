import SwiftUI

struct ContentView: View {
  let link: WatchLink

  @State private var tracker = WalkTracker()
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      if let walk = link.localWalk {
        if walk.finishedAt == nil {
          WalkProgressView(steps: link.displayedSteps, goal: WalkExchange.goal, issue: tracker.issue,
            onEnd: link.finishWalk)
        } else {
          WalkDoneView(linkedToPhone: walk.linked, onDone: link.dismissSummary)
        }
      } else {
        StartWalkView(linkedToPhone: link.availableWalk != nil, onStart: link.startWalk)
      }
    }
    .scrollIndicators(.hidden)
    .onChange(of: link.localWalk?.request, initial: true) { _, _ in
      tracker.stop()
      tracker = WalkTracker()
      if scenePhase == .active { startTracking() }
    }
    .onChange(of: link.localWalk?.finishedAt) { _, finishedAt in
      if finishedAt != nil { tracker.stop() }
    }
    .onChange(of: tracker.steps) { _, steps in link.recordSteps(steps) }
    .task(id: scenePhase) {
      if scenePhase == .active {
        startTracking()
        await link.foreground()
      } else if scenePhase == .background {
        tracker.stop()
      }
    }
  }

  private func startTracking() {
    guard let walk = link.localWalk, walk.finishedAt == nil else { return }
    tracker.start(from: walk.request.startedAt)
  }
}

#Preview {
  ContentView(link: WatchLink())
}
