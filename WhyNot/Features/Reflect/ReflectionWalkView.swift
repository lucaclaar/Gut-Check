import SwiftUI

struct ReflectionWalkView: View {
  let session: ReflectionSession
  let watchAppInstalled: Bool
  @State private var pedometer = WalkTracker()
  @Environment(\.scenePhase) private var scenePhase

  private var trackingStatus: String {
    if session.watchWalkSteps != nil { return "Synced with Apple Watch" }
    // The iPhone keeps counting either way; the Watch is an optional way to leave it behind.
    if watchAppInstalled { return "Your Apple Watch can track this walk, so you can leave your iPhone behind. Carrying it works too." }
    return pedometer.status
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Text("No screens needed.").font(GutTheme.display())
          .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 46)
        ZStack {
          Circle().stroke(Color("GutRingTrack"), lineWidth: 18)
          Circle().trim(from: 0, to: min(Double(session.currentWalkSteps) / Double(WalkExchange.goal), 1))
            .stroke(.white, style: StrokeStyle(lineWidth: 18, lineCap: .round)).rotationEffect(
              .degrees(-90))
          VStack(spacing: 22) {
            Text(session.currentWalkSteps, format: .number).font(GutTheme.display(56)).contentTransition(
              .numericText())
            Text("of \(WalkExchange.goal.formatted()) steps").font(.subheadline).foregroundStyle(GutTheme.muted)
          }
        }
        .frame(width: 242, height: 242).padding(.top, 74).accessibilityElement(children: .combine)
        MascotView(name: "MascotBestCase4", width: 140, height: 129).padding(.top, 48)
        Text(trackingStatus).font(.footnote).foregroundStyle(GutTheme.muted)
          .multilineTextAlignment(.center).padding(.top, 30)
      }
      .padding(.horizontal, 24).padding(.bottom, 40)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "End walk early", prominent: false, action: endWalk)
        .padding(.horizontal, 24).padding(.bottom, 22)
    }
    .background(GutBackground(asset: "32-110-Glow")).toolbar(.hidden, for: .navigationBar)
    .onAppear(perform: startTracking).onDisappear(perform: pedometer.stop)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { startTracking() }
    }
    .onChange(of: pedometer.steps) { _, steps in session.updatePhoneWalkSteps(steps) }
  }
  private func startTracking() {
    guard let walk = session.currentWalk else { return }
    pedometer.start(from: walk.startedAt)
  }
  private func endWalk() {
    guard session.path.last == .walk else { return }
    pedometer.stop()
    session.endWalk(steps: session.currentWalkSteps)
  }
}
