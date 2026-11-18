import SwiftUI

struct ReflectionWalkView: View {
  let session: ReflectionSession
  @State private var pedometer = WalkTracker()
  @Environment(\.scenePhase) private var scenePhase
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        Text("No screens needed.").font(GutTheme.display())
          .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 46)
        ZStack {
          Circle().stroke(Color("GutRingTrack"), lineWidth: 18)
          Circle().trim(from: 0, to: min(Double(pedometer.steps) / 2_000, 1))
            .stroke(.white, style: StrokeStyle(lineWidth: 18, lineCap: .round)).rotationEffect(
              .degrees(-90))
          VStack(spacing: 22) {
            Text(pedometer.steps, format: .number).font(GutTheme.display(56)).contentTransition(
              .numericText())
            Text("of 2,000 steps").font(.subheadline).foregroundStyle(GutTheme.muted)
          }
        }
        .frame(width: 242, height: 242).padding(.top, 74).accessibilityElement(children: .combine)
        MascotView(name: "MascotBestCase4", width: 140, height: 129).padding(.top, 48)
        Text(pedometer.status).font(.footnote).foregroundStyle(GutTheme.muted)
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
    .onAppear {
          PhoneWatchLink.shared.finishedWalkSteps = nil  // new: ignore old messages
          pedometer.start()
        }
        .onDisappear(perform: pedometer.stop)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { pedometer.start() } else if phase == .background { pedometer.stop() }
    }
    .onChange(of: pedometer.steps) { _, steps in if steps >= 2_000 { endWalk() } }
  }
  private func endWalk() {
    guard session.path.last == .walk else { return }
    pedometer.stop()
    session.endWalk(steps: pedometer.steps)
  }
}
