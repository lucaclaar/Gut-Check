import SwiftUI

struct ContentView: View {
  private enum ActivitySource: Equatable {
    case walk(WalkExchange.Request, steps: Int)
    case turbo(id: UUID, startedAt: Date, phase: TurboPhase)
  }

  private enum TurboDraftAction {
    case save, discard
  }

  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("hasStarted") private var hasStarted = false
  @State private var session = ReflectionSession(onDecisionSaved: { decision in
    ReflectionReminder.shared.update(for: decision)
  })
  @State private var turbo = TurboSession()
  @State private var activities = GutActivityCoordinator()
  @State private var turboActivityID = UUID()
  @State private var turboStartedAt = Date.now
  @State private var remoteActivity: GutActivitySnapshot?
  @State private var failedTurboDraftAction: TurboDraftAction?
  @State private var showTurboDraftError = false
  private let reminders = ReflectionReminder.shared
  private let watchLink = PhoneWatchLink.shared

  private var activitySource: ActivitySource? {
    if let walk = session.currentWalk { return .walk(walk, steps: session.currentWalkSteps) }
    guard session.path.last == .turboGame else { return nil }
    switch turbo.phase {
    case .countdown, .playing, .paused:
      return .turbo(id: turboActivityID, startedAt: turboStartedAt, phase: turbo.phase)
    default:
      return nil
    }
  }

  var body: some View {
    activityNavigation
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
    .alert("Couldn’t update your Turbo draft", isPresented: $showTurboDraftError) {
      Button("Try again") {
        switch failedTurboDraftAction {
        case .save: saveTurboForLater()
        case .discard: discardTurbo()
        case nil: break
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your round is still here. Try again or keep playing.")
    }
  }

  private var activityNavigation: some View {
    navigation
    .onChange(of: activitySource, initial: true) { _, source in publishActivity(source) }
    .onChange(of: scenePhase, initial: true) { _, phase in
      activities.setForeground(phase == .active)
    }
    .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
      activities.refreshCloud()
      if let id = remoteActivity?.id { remoteActivity = activities.remoteActivity(id: id) }
    }
    .onOpenURL(perform: openActivity)
    .sheet(item: $remoteActivity) { activity in
      RemoteActivityView(activity: activity)
    }
  }

  private var navigation: some View {
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
          }, reflect: reflectOnTurboOptions)
        case .turboFeeling:
          TurboFeelingView(session: turbo, replay: startTurbo)
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
    .onChange(of: session.path) { _, path in
      if path.last == .turboResult { turbo.returnToResult() }
    }
    .onChange(of: turbo.phase) { _, phase in
      if phase == .saved, session.path.last == .turboFeeling {
        session.path.append(.turboSaved)
      }
    }
    .onChange(of: session.path.isEmpty) { _, atHome in if atHome { openReminder() } }
  }

  private func publishActivity(_ source: ActivitySource?) {
    switch source {
    case .walk(let walk, let steps):
      activities.update(.init(id: walk.id, startedAt: walk.startedAt, stage: .walk,
        expiresAt: walk.startedAt.addingTimeInterval(8 * 60 * 60)), steps: steps)
    case .turbo(let id, let startedAt, let phase):
      let now = Date.now
      let stage: GutActivitySnapshot.Stage
      let expiresAt: Date
      switch phase {
      case .countdown:
        expiresAt = now.addingTimeInterval(turbo.countdownRemaining)
        stage = .turboCountdown(deadline: expiresAt)
      case .playing:
        expiresAt = now.addingTimeInterval(turbo.remaining)
        stage = .turboRound(deadline: expiresAt)
      case .paused:
        expiresAt = now.addingTimeInterval(30 * 60)
        stage = .turboPaused(secondsLeft: turbo.secondsRemaining)
      default:
        return
      }
      activities.update(.init(id: id, startedAt: startedAt, stage: stage, expiresAt: expiresAt))
    case nil:
      activities.update(nil)
    }
  }

  private func openActivity(_ url: URL) {
    guard url.scheme == GutActivitySnapshot.homeURL.scheme else { return }
    guard let id = GutActivitySnapshot.id(from: url) else { return }
    if session.currentWalk?.id == id || (session.path.last == .turboGame && turboActivityID == id) {
      return
    }
    remoteActivity = activities.remoteActivity(id: id)
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
    guard let id = reminders.openedID, !session.path.contains(.walk), session.path.last != .turboGame else { return }
    reminders.clearOpenedID()
    if session.resumeDecision(id) {
      hasStarted = true
      reminders.cancel(for: id)
    }
  }

  private func saveTurboForLater() {
    if turbo.saveForLater() {
      session.home()
    } else {
      failedTurboDraftAction = .save
      showTurboDraftError = true
    }
  }

  private func discardTurbo() {
    do {
      try turbo.discardCurrent()
      session.home()
    } catch {
      failedTurboDraftAction = .discard
      showTurboDraftError = true
    }
  }

  private func startTurbo() {
    if turbo.start() {
      turboActivityID = UUID()
      turboStartedAt = .now
      session.path = [.turboSetup, .turboGame]
    } else if let concern = turbo.safetyConcern {
      session.safetyConcern = concern
    }
  }

  private func reflectOnTurboOptions() {
    let options = turbo.filledOptions.map { $0.text }.joined(separator: ", ")
    session.start(question: "Which option feels right: \(options)?")
  }
}

#Preview {
  ContentView()
}
