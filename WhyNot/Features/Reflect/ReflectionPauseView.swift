import SwiftUI

struct ReflectionPauseView: View {
  private enum Panel: String, Identifiable {
    case explanation, nextSteps
    var id: Self { self }
  }

  private enum NextStep {
    case walk, cards, sleep
  }

  let session: ReflectionSession
  let lastWatchWalk: WalkExchange.Update?
  @State private var generator = AppleReflectionCardGenerator()
  @State private var panel: Panel?
  @State private var pendingStep: NextStep?
  @ScaledMetric(relativeTo: .subheadline) private var watchWordmarkHeight = 16.0

  private var insight: ReflectionInsight { session.interpretedAnswers }
  private var needsTime: Bool { session.needsMoreTime || insight.leaning == .mixed }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          Spacer(minLength: 24)
          result
          Spacer(minLength: 40)
          actions
        }
        .frame(maxWidth: 500, minHeight: max(0, geometry.size.height - 40))
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
    }
    .background(GutBackground(asset: "32-94-Glow", origin: CGPoint(x: -80, y: 40)))
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $panel, onDismiss: performNextStep) { item in
      switch item {
      case .explanation:
        AnswersSheet(answers: insight.evidence, summary: insight.summary)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      case .nextSteps:
        nextSteps
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
    }
    .task(id: session.answers) {
      guard session.insight == nil else { return }
      let answers = session.answers
      let dilemma = session.question
      guard let interpretation = await generator.interpret(question: dilemma, answers: answers),
        !Task.isCancelled, session.path.last == .pause, session.question == dilemma,
        session.answers == answers
      else { return }
      session.insight = interpretation
    }
  }

  private var result: some View {
    VStack(spacing: 10) {
      MascotView(name: insight.leaning.mascot, width: 216, height: 158)
        .padding(.bottom, 8)
      Text(insight.leaning.title)
        .font(GutTheme.display(29))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Button {
        panel = .explanation
      } label: {
        Label("Why this?", systemImage: "info.circle")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(GutTheme.purple)
          .frame(minHeight: 44)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  private var actions: some View {
    VStack(spacing: 10) {
      if needsTime {
        GutButton(title: "Take more time", action: showNextSteps)
        GutButton(title: "I’ve made my decision", prominent: false, action: session.ready)
      } else {
        GutButton(title: "I’ve made my decision", action: session.ready)
        GutButton(title: "I’m still unsure", prominent: false, action: showNextSteps)
      }
    }
  }

  private var nextSteps: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          GutButton(title: "Let's walk") { select(.walk) }
            .accessibilityIdentifier("reflect.walk.start")
          GutButton(title: "Explore new cards", prominent: false) { select(.cards) }
          GutButton(title: "Sleep on it", prominent: false) { select(.sleep) }
          VStack(spacing: 6) {
            watchCredit
            if let lastWatchWalk {
              Text("Last Watch walk · \(lastWatchWalk.steps.formatted()) steps")
                .font(.footnote)
                .foregroundStyle(GutTheme.muted)
            }
          }
          .padding(.top, 4)
        }
        .frame(maxWidth: 500)
        .padding(24)
        .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
      .navigationTitle("Take more time")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { panel = nil }
            .labelStyle(.iconOnly)
        }
      }
    }
  }

  private func showNextSteps() {
    panel = .nextSteps
  }

  private func select(_ step: NextStep) {
    pendingStep = step
    panel = nil
  }

  private func performNextStep() {
    guard let step = pendingStep else { return }
    pendingStep = nil
    session.needsMoreTime = true
    switch step {
    case .walk: session.beginWalk()
    case .cards: session.keepReflecting(using: generator.isDeviceAvailable ? generator : nil)
    case .sleep: session.sleepOnIt()
    }
  }

  private var watchCredit: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 7) {
        watchPrefix
        watchWordmark
      }
      VStack(alignment: .leading, spacing: 6) {
        watchPrefix
        watchWordmark
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Track with your Apple Watch")
  }

  private var watchPrefix: some View {
    Text("Track with your")
      .font(.footnote)
      .foregroundStyle(GutTheme.muted)
  }

  private var watchWordmark: some View {
    Image(decorative: "AppleWatchWordmark")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: watchWordmarkHeight * (3840.0 / 847.0), height: watchWordmarkHeight)
      .foregroundStyle(.white)
  }
}
