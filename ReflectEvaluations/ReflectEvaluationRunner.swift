import Foundation
#if canImport(GutCheck)
@testable import GutCheck
#endif

actor ReflectEvaluationRunner {
  nonisolated struct Response: Codable, Sendable {
    enum Outcome: String, Codable, Sendable {
      case personalized, standard, support, modelBlocked, noDeck
    }

    let outcome: Outcome
    let secondsToDeck: Double?
    let cards: [String]
    let lenses: [String]
    let validDeck: Bool
    let support: String?
    let attemptedSources: [String]
    let blockReason: String?
  }

  private var previous: Task<Response, Error>?

  func run(_ example: ReflectEvaluationCase, preferCloud: Bool) async throws -> Response {
    let predecessor = previous
    // Multiple samples can reach an evaluator together. Queue generation so the measured
    // request sees the same model load as a single Reflect session.
    let request = Task { @MainActor in
      _ = await predecessor?.result
      try Task.checkCancellation()
      return try await Self.measure(example, preferCloud: preferCloud)
    }
    previous = request
    return try await withTaskCancellationHandler {
      try await request.value
    } onCancel: {
      request.cancel()
    }
  }

  @MainActor
  private static func measure(_ example: ReflectEvaluationCase, preferCloud: Bool) async throws
    -> Response
  {
    guard let lens = ReflectionLens(rawValue: example.lens.rawValue) else {
      throw RunnerError.invalidLens
    }
    let generator = ObservedGenerator()
    let session = ReflectionSession(storageURL: URL.temporaryDirectory.appending(path: UUID().uuidString))
    defer { session.cancelCardPreparation() }
    session.start(question: example.dilemma)
    session.lens = lens

    if example.expectedSupport == nil {
      generator.base.prewarmDevice(for: example.dilemma)
      try await Task.sleep(for: .seconds(1))
    }
    let started = ContinuousClock.now
    session.shuffle(using: generator, preferCloud: preferCloud, startedAt: started)
    while session.isPreparingCards {
      guard ContinuousClock.now < started + .seconds(7) else { throw RunnerError.didNotFinish }
      try await Task.sleep(for: .milliseconds(10))
    }

    let elapsed = (ContinuousClock.now - started).components
    let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    let cards = session.path.last == .cards ? session.cards : []
    let outcome: Response.Outcome
    if session.safetyConcern != nil {
      outcome = .support
    } else if session.showCardGenerationIssue {
      outcome = .modelBlocked
    } else if session.path.last == .cards {
      outcome = session.usesPersonalizedCards ? .personalized : .standard
    } else {
      outcome = .noDeck
    }

    let questions = cards.map(\.text)
    return Response(outcome: outcome, secondsToDeck: cards.isEmpty ? nil : seconds,
      cards: questions, lenses: cards.map { $0.lens.rawValue },
      validDeck: ReflectionQuestion.personalized(questions, for: lens) != nil,
      support: session.safetyConcern?.rawValue, attemptedSources: generator.attemptedSources,
      blockReason: outcome == .modelBlocked ? generator.blockReason : nil)
  }

  private enum RunnerError: Error {
    case invalidLens, didNotFinish
  }

  @MainActor
  private final class ObservedGenerator: ReflectionCardGenerating {
    let base = AppleReflectionCardGenerator()
    private(set) var attemptedSources: [String] = []
    private(set) var blockReason: String?

    func generate(question: String, lens: ReflectionLens, using source: ReflectionCardSource)
      async -> ReflectionCardGenerationResult
    {
      attemptedSources.append(source == .cloud ? "cloud" : "device")
      let result = await base.generate(question: question, lens: lens, using: source)
      if !Task.isCancelled {
        switch result {
        case .blocked(let reason): blockReason = reason.rawValue
        case .refused: blockReason = "modelRefusal"
        case .questions, .unavailable: break
        }
      }
      return result
    }
  }
}
