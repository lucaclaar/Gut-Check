import SwiftUI

struct ContentView: View {
  @AppStorage("hasStarted") private var hasStarted = false
  @State private var session = ReflectionSession()

  var body: some View {
    NavigationStack(path: $session.path) {
      Group {
        if hasStarted {
          ModeSelectionView(session: session)
        } else {
          WelcomeView { hasStarted = true }
        }
      }
      .navigationDestination(for: ReflectionRoute.self) { route in
        switch route {
        case .setup: ReflectionSetupView(session: session)
        case .cards: ReflectionCardsView(session: session)
        case .pause: ReflectionPauseView(session: session)
        case .walk: ReflectionWalkView(session: session)
        case .returnFromWalk: ReflectionReturnView(session: session)
        case .decision: ReflectionDecisionView(session: session)
        case .saved: ReflectionSavedView(session: session)
        }
      }
    }
    .font(.system(.body, design: .rounded))
    .tint(.white)
    .preferredColorScheme(.dark)
    .sheet(item: $session.safetyConcern) { concern in
      SafetySupportView(concern: concern)
    }
    .alert("Couldn’t save your decision", isPresented: $session.showSaveError) {
      Button("Try again", action: session.saveDecision)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(session.saveError)
    }
  }
}

#Preview {
  ContentView()
}
