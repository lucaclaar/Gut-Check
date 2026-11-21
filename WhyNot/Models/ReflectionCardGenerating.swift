enum ReflectionCardSource {
  case cloud, device
}

enum ReflectionCardGenerationResult {
  enum BlockReason: String {
    case appleGuardrail, modelRequestedSupport, outputScreening
  }

  case questions([String])
  case unavailable
  case blocked(BlockReason)
  case refused
}

@MainActor
protocol ReflectionCardGenerating {
  func generate(question: String, lens: ReflectionLens, using source: ReflectionCardSource)
    async -> ReflectionCardGenerationResult
  func followUp(question: String, lens: ReflectionLens, context: ReflectionFollowUp)
    async -> ReflectionCardGenerationResult
}

extension ReflectionCardGenerating {
  func followUp(question: String, lens: ReflectionLens, context: ReflectionFollowUp)
    async -> ReflectionCardGenerationResult { .unavailable }
}
