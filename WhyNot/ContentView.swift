import SwiftUI

struct ContentView: View {
  @AppStorage("hasStarted") private var hasStarted = false
  @State private var session = ReflectionSession(onDecisionSaved: { decision in
    ReflectionReminder.shared.update(for: decision)
  })
  @State private var turbo = TurboSession()
  private let reminders = ReflectionReminder.shared
  private let watchLink = PhoneWatchLink.shared

  var body: some View {
    NavigationStack(path: $session.path) {
      Group {
        if hasStarted {
          ModeSelectionView(session: session, turbo: turbo,
            resume: resume, delete: delete) {
            turbo.prepareNew()
            session.path = [.turboSetup]
          }
        } else {
          WelcomeView { hasStarted = true }
        }
      }
      .navigationDestination(for: ReflectionRoute.self) { route in
        switch route {
        case .setup: ReflectionSetupView(session: session)
        case .cards: ReflectionCardsView(session: session)
        case .pause:
          ReflectionPauseView(session: session, lastWatchWalk: watchLink.latestStandaloneWalk)
        case .walk:
          ReflectionWalkView(session: session, watchAppInstalled: watchLink.isWatchAppInstalled)
        case .returnFromWalk: ReflectionReturnView(session: session)
        case .decision: ReflectionDecisionView(session: session)
        case .saved: ReflectionSavedView(session: session)
        case .deferred: ReflectionDeferredView(session: session)
        case .turboSetup:
          TurboSetupView(session: turbo, start: startTurbo,
            showSafety: { session.safetyConcern = $0 },
            home: session.home, saveForLater: saveTurboForLater, discard: discardTurbo)
        case .turboGame:
          TurboGameView(session: turbo, finish: {
            session.path = [.turboSetup, .turboResult]
          }, restart: startTurbo, saveForLater: saveTurboForLater, discard: discardTurbo)
        case .turboResult:
          TurboResultView(session: turbo, replay: startTurbo, proceed: {
            turbo.continueToFeeling()
            if turbo.phase == .feeling { session.path.append(.turboFeeling) }
          }, reflect: {
            session.start(question: "Which option feels right: \(turbo.filledOptions.map(\.text).joined(separator: ", "))?")
          })
        case .turboFeeling:
          TurboFeelingView(session: turbo, replay: startTurbo)
            .onChange(of: turbo.phase) { _, phase in
              if phase == .saved { session.path.append(.turboSaved) }
            }
        case .turboSaved:
          TurboSavedView(session: turbo, home: session.home, replay: startTurbo)
        }
      }
    }
    .font(.system(.body, design: .rounded))
    .tint(.white)
    .preferredColorScheme(.dark)
    .onChange(of: session.walkStateForWatch, initial: true) { _, state in watchLink.publish(state) }
    .onChange(of: watchLink.update(for: session.currentWalk?.id), initial: true) { _, update in
      if let update { session.updateWalkFromWatch(update) }
    }
    .onChange(of: watchLink.completedLinkedWalks, initial: true) { _, updates in
      session.reconcileCompletedWalks(with: updates)
    }
    .onChange(of: reminders.openedID, initial: true) { _, _ in openReminder() }
    .onChange(of: session.path.isEmpty) { _, atHome in if atHome { openReminder() } }
    .sheet(item: $session.safetyConcern) { concern in
      SafetySupportView(concern: concern)
    }
    .alert("Couldn’t save your decision", isPresented: $session.showSaveError) {
      Button("Try again", action: session.retrySave)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(session.saveError)
    }
    .alert("Couldn’t prepare these cards", isPresented: $session.showCardGenerationIssue) {
      Button("OK", role: .cancel) {}
      Button("Help and support") { session.safetyConcern = .support }
    } message: {
      Text("Try changing your dilemma or open Help and support.")
    }
    .alert("You’ve explored these questions", isPresented: $session.showNoNewCards) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Try taking a walk or give yourself more time before you decide.")
    }
  }

  private func resume(_ activity: RecentDecision) {
    switch activity.mode {
    case .reflect:
      if session.resumeDecision(activity.id) { reminders.cancel(for: activity.id) }
    case .turbo:
      if turbo.resumeDecision(activity.id) { session.path = [.turboSetup] }
    }
  }

  private func delete(_ activity: RecentDecision) throws {
    switch activity.mode {
    case .reflect:
      try session.deleteDecision(activity.id)
      reminders.cancel(for: activity.id)
    case .turbo:
      try turbo.deleteDecision(activity.id)
    }
  }

  private func openReminder() {
    guard let id = reminders.openedID, !session.path.contains(.walk) else { return }
    reminders.clearOpenedID()
    if session.resumeDecision(id) {
      hasStarted = true
      reminders.cancel(for: id)
    }
  }

  private func saveTurboForLater() {
    if turbo.saveForLater() { session.home() }
  }

  private func discardTurbo() {
    try? turbo.discardCurrent()
    session.home()
  }

  private func startTurbo() {
    if turbo.start() { session.path = [.turboSetup, .turboGame] }
    else if let concern = turbo.safetyConcern { session.safetyConcern = concern }
  }
}

#Preview {
  ContentView()
}
