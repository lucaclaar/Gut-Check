enum ReflectionCardSource {
  case cloud, device
}

enum ReflectionCardGenerationResult {
  case questions([String])
  case unavailable
  case blocked
  case refused
}

@MainActor
protocol ReflectionCardGenerating {
  func generate(question: String, lens: ReflectionLens, using source: ReflectionCardSource)
    async -> ReflectionCardGenerationResult
}
