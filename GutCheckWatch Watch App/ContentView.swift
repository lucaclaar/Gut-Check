import SwiftUI

struct ContentView: View {
    /// The three screens of the design.
    enum Stage { case start, walking, done }

    @State private var stage: Stage = .start
    @State private var tracker = WalkTracker()  // shared from the iPhone app (Step 5)
    @Environment(\.scenePhase) private var scenePhase
    private let goal = 2_000
    
  var body: some View {
      Group {
         switch stage {
         case .start: StartWalkView(onStart: startWalk)
         case .walking: WalkProgressView(steps: tracker.steps, goal: goal)
         case .done: WalkDoneView()
         }
       }
       // Every time the step count changes, check if the goal is reached.
       .onChange(of: tracker.steps) { _, steps in
         if stage == .walking && steps >= goal { finishWalk() }
       }
       // React when the app goes to the background or comes back.
       .onChange(of: scenePhase) { _, phase in
         switch (stage, phase) {
         case (.walking, .active): tracker.start()
         case (.walking, .background): tracker.stop()
         case (.done, .background):
           // Next time the app opens, start fresh.
           stage = .start
           tracker = WalkTracker()
         default: break
         }
       }
     }

     private func startWalk() {
       stage = .walking
       tracker.start()
     }

     private func finishWalk() {
       tracker.stop()
       stage = .done
     }
  }

#Preview {
  ContentView()
}
