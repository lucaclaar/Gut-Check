import Evaluations
import Foundation

nonisolated struct ReflectDeckEvaluation: Evaluation {
  typealias Sample = ModelSample<Value>
  typealias Subject = ModelSubject<Value>

  enum Value: Codable, Sendable {
    case expected(ReflectEvaluationCase)
    case observed(ReflectEvaluationRunner.Response)
  }

  let dataset: ArrayLoader<ModelSample<Value>>
  let preferCloud: Bool
  private let runner = ReflectEvaluationRunner()

  let personalizedWithinFiveSeconds = Metric("Personalized deck within 5 seconds")
  let standardDeck = Metric("Standard deck shown")
  let modelBlocked = Metric("Model block or refusal")
  let deckContract = Metric("Six valid questions and correct lenses")
  let contextCoverage = Metric("Expected details present")
  let unsupportedDetails = Metric("Known unsupported detail markers absent")
  let secondsToDeck = Metric("Seconds until deck is ready")
  let safetyGate = Metric("Support opened before any model request")

  init(cases: [ReflectEvaluationCase], preferCloud: Bool = false) {
    dataset = ArrayLoader(samples: cases.map {
      ModelSample(prompt: $0.dilemma, expected: .expected($0))
    })
    self.preferCloud = preferCloud
  }

  func subject(from sample: ModelSample<Value>) async throws -> ModelSubject<Value> {
    guard case .expected(let example) = sample.expected else { throw EvaluationInputError.missingCase }
    let response = try await runner.run(example, preferCloud: preferCloud)
    return ModelSubject(value: .observed(response))
  }

  var evaluators: [any EvaluatorProtocol<Sample, Subject>] {
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, example.expectedSupport == nil,
        case .observed(let response) = subject.value else { return personalizedWithinFiveSeconds.ignore() }
      let ready = response.outcome == .personalized && (response.secondsToDeck ?? .infinity) <= 5
      return ready ? personalizedWithinFiveSeconds.passing()
        : personalizedWithinFiveSeconds.failing(rationale: response.outcome.rawValue)
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, example.expectedSupport == nil,
        case .observed(let response) = subject.value else { return standardDeck.ignore() }
      return response.outcome == .standard ? standardDeck.passing() : standardDeck.failing()
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, example.expectedSupport == nil,
        case .observed(let response) = subject.value else { return modelBlocked.ignore() }
      return response.outcome == .modelBlocked ? modelBlocked.passing(rationale: response.blockReason)
        : modelBlocked.failing()
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, case .observed(let response) = subject.value,
        !response.cards.isEmpty else { return deckContract.ignore() }
      return response.validDeck && response.lenses == example.lens.expectedLenses
        ? deckContract.passing() : deckContract.failing()
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, !example.details.isEmpty,
        case .observed(let response) = subject.value, response.outcome == .personalized
      else { return contextCoverage.ignore() }
      let text = response.cards.joined(separator: "\n")
      let missing = example.details.filter { terms in
        !terms.contains { text.localizedStandardContains($0) }
      }
      return contextCoverage.scoring(
        Double(example.details.count - missing.count) / Double(example.details.count),
        rationale: missing.isEmpty ? nil : "Missing: " + missing.map { $0.joined(separator: " / ") }.joined(separator: ", "))
    }
    Evaluator { _, subject in
      guard case .observed(let response) = subject.value, let seconds = response.secondsToDeck
      else { return secondsToDeck.ignore() }
      return secondsToDeck.scoring(seconds)
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, let markers = example.unsupportedDetails,
        !markers.isEmpty,
        case .observed(let response) = subject.value, response.outcome == .personalized
      else { return unsupportedDetails.ignore() }
      let text = response.cards.joined(separator: "\n")
      let unexpected = markers.filter { text.localizedStandardContains($0) }
      return unexpected.isEmpty ? unsupportedDetails.passing()
        : unsupportedDetails.failing(rationale: unexpected.joined(separator: ", "))
    }
    Evaluator { sample, subject in
      guard case .expected(let example) = sample.expected, let expected = example.expectedSupport,
        case .observed(let response) = subject.value else { return safetyGate.ignore() }
      return response.outcome == .support && response.support == expected && response.attemptedSources.isEmpty
        ? safetyGate.passing() : safetyGate.failing(rationale: response.outcome.rawValue)
    }
  }

  func aggregateMetrics(using aggregator: inout MetricsAggregator) {
    aggregator.computeMean(of: personalizedWithinFiveSeconds)
    aggregator.computeMean(of: standardDeck)
    aggregator.computeMean(of: modelBlocked)
    aggregator.computeMean(of: deckContract)
    aggregator.computeMean(of: contextCoverage)
    aggregator.computeMean(of: unsupportedDetails)
    aggregator.computeMean(of: safetyGate)
    aggregator.computeMedian(of: secondsToDeck)
    aggregator.custom(of: secondsToDeck, label: "95th percentile seconds to deck") { values in
      guard !values.isEmpty else { return -1 }
      return values.sorted()[Int(ceil(Double(values.count) * 0.95)) - 1]
    }
  }

  private enum EvaluationInputError: Error {
    case missingCase
  }
}
