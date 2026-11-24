import Foundation

@MainActor
final class ReflectionCardPreparation {
  enum Outcome {
    case personalized([ReflectionQuestion])
    case standard
    case blocked
    case refused
  }

  private let generator: any ReflectionCardGenerating
  private let question: String
  private let lens: ReflectionLens
  private let followUp: ReflectionFollowUp?
  private let clock = ContinuousClock()
  private let deadline: ContinuousClock.Instant
  private let cloudDeadline: ContinuousClock.Instant
  private var source: ReflectionCardSource?
  private var generation: Task<Void, Never>?
  private var countdown: Task<Void, Never>?
  private var completion: ((Outcome) -> Void)?

  init(generator: any ReflectionCardGenerating, question: String, lens: ReflectionLens,
    startedAt: ContinuousClock.Instant, timeLimit: Duration = .seconds(5),
    cloudLimit: Duration = .seconds(2), followUp: ReflectionFollowUp? = nil
  ) {
    self.generator = generator
    self.question = question
    self.lens = lens
    self.followUp = followUp
    deadline = startedAt + timeLimit
    cloudDeadline = min(startedAt + cloudLimit, deadline)
  }

  func start(preferCloud: Bool, completion: @escaping (Outcome) -> Void) {
    self.completion = completion
    guard clock.now < deadline else { finish(.standard); return }
    trySource(preferCloud ? .cloud : .device)
    let clock = clock
    let cloudDeadline = cloudDeadline
    let deadline = deadline
    // This task can finish the request even if a model takes time to observe cancellation.
    countdown = Task { [weak self] in
      do {
        if preferCloud {
          try await clock.sleep(until: cloudDeadline)
          if self?.source == .cloud, clock.now < deadline { self?.trySource(.device) }
        }
        try await clock.sleep(until: deadline)
        self?.finish(.standard)
      } catch {}
    }
  }

  func cancel() {
    completion = nil
    source = nil
    generation?.cancel()
    countdown?.cancel()
    generation = nil
    countdown = nil
  }

  private func trySource(_ source: ReflectionCardSource) {
    generation?.cancel()
    self.source = source
    let generator = generator
    let question = question
    let lens = lens
    let followUp = followUp
    generation = Task { [weak self] in
      guard !Task.isCancelled else { return }
      let result = if let followUp {
        await generator.followUp(question: question, lens: lens, context: followUp)
      } else {
        await generator.generate(question: question, lens: lens, using: source)
      }
      guard !Task.isCancelled else { return }
      self?.receive(result, from: source)
    }
  }

  private func receive(_ result: ReflectionCardGenerationResult, from source: ReflectionCardSource) {
    guard self.source == source else { return }
    switch result {
    case .blocked: finish(.blocked)
    case .refused: finish(.refused)
    case .questions(let questions):
      guard clock.now < deadline else { finish(.standard); return }
      let cards: [ReflectionQuestion]? = if let followUp {
        followUp.generatedDeck(questions, for: lens)
      } else if let deck = ReflectionQuestion.personalized(questions, for: lens),
        source == .device || !ReflectionQuestion.hasRepeatedAngle(in: deck.map(\.text))
      {
        deck
      } else {
        nil
      }
      if let cards {
        finish(.personalized(cards))
      } else {
        useFallback(after: source)
      }
    case .unavailable:
      useFallback(after: source)
    }
  }

  private func useFallback(after source: ReflectionCardSource) {
    if source == .cloud, clock.now < deadline {
      trySource(.device)
    } else {
      finish(.standard)
    }
  }

  private func finish(_ outcome: Outcome) {
    let completion = completion
    cancel()
    completion?(outcome)
  }
}
