import Evaluations
import Foundation
import FoundationModels
import TabularData
import Testing
@testable import GutCheck

@Suite(.serialized)
struct ReflectEvaluationTests {
  private static let baseline = ReflectDeckEvaluation(cases: ReflectEvaluationCases.dilemmas)
  private static let safety = ReflectDeckEvaluation(cases: ReflectEvaluationCases.safety)
  private static let cloud = ReflectDeckEvaluation(cases: ReflectEvaluationCases.dilemmas, preferCloud: true)

  @Test(
    .enabled(if: SystemLanguageModel.default.isAvailable, "Requires on-device Apple Intelligence."),
    .evaluates(Self.baseline, info: ["Mode": "On-device baseline"], recordTranscripts: false))
  func onDeviceBaseline() {
    verifyDeckRun(Self.baseline)
  }

  @Test(.evaluates(Self.safety, info: ["Mode": "Local safety gate"], recordTranscripts: false))
  func localSafetyGate() {
    let result = EvaluationContext.current.result
    #expect(result.detailed.rows.count == ReflectEvaluationCases.safety.count)
    #expect(result.errors.inferenceFailureCount == 0)
    #expect(result.errors.evaluatorFailureCount == 0)
    #expect(result.aggregateValue(.mean(of: Self.safety.safetyGate)) == 1)
  }

  @Test(
    .enabled("Requires an explicitly enabled PCC evaluation and an entitled test app.") {
      guard ProcessInfo.processInfo.environment["WHYNOT_EVALUATE_PCC"] == "1" else { return false }
      return await MainActor.run { AppleReflectionCardGenerator().isCloudAvailable }
    },
    .evaluates(Self.cloud, info: ["Mode": "Cloud-first with production fallback"], recordTranscripts: false))
  func cloudFirstComparison() {
    verifyDeckRun(Self.cloud)
  }

  private func verifyDeckRun(_ evaluation: ReflectDeckEvaluation) {
    let result = EvaluationContext.current.result
    #expect(result.detailed.rows.count == ReflectEvaluationCases.dilemmas.count)
    #expect(result.errors.inferenceFailureCount == 0)
    #expect(result.errors.evaluatorFailureCount == 0)
    #expect(result.aggregateValue(.mean(of: evaluation.deckContract)) == 1)
    print(result.groupedSummary)
  }
}
