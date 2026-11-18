import Foundation

nonisolated enum WalkExchange {
  static let goal = 2_000
  static let inactiveContext = ["walkActive": false]
  static let requestPhoneStateKey = "requestPhoneWalkState"

  struct Request: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date

    init(id: UUID = UUID(), startedAt: Date = .now) {
      self.id = id
      self.startedAt = startedAt
    }

    init?(payload: [String: Any]) {
      guard let value = payload["walkID"] as? String, let id = UUID(uuidString: value),
        let startedAt = payload["walkStartedAt"] as? Date else { return nil }
      self.init(id: id, startedAt: startedAt)
    }

    var payload: [String: Any] { ["walkID": id.uuidString, "walkStartedAt": startedAt] }
  }

  struct Completion: Codable, Equatable, Sendable {
    let id: UUID
    let steps: Int

    init(id: UUID, steps: Int) {
      self.id = id
      self.steps = steps
    }

    init?(payload: [String: Any]) {
      guard let value = payload["walkID"] as? String, let id = UUID(uuidString: value),
        let steps = payload["walkSteps"] as? Int, steps >= 0 else { return nil }
      self.init(id: id, steps: steps)
    }

    var payload: [String: Any] { ["walkID": id.uuidString, "walkSteps": steps] }
  }

  struct PhoneState: Equatable, Sendable {
    var request: Request?
    var steps = 0
    var completion: Completion?
    var updatedAt: Date?

    init(request: Request? = nil, steps: Int = 0, completion: Completion? = nil) {
      self.request = request
      self.steps = steps
      self.completion = completion
    }

    init(payload: [String: Any]) {
      request = Request(payload: payload)
      steps = max(0, payload["phoneSteps"] as? Int ?? 0)
      updatedAt = payload["phoneUpdatedAt"] as? Date
      if let completion = payload["phoneCompletion"] as? [String: Any] {
        self.completion = Completion(payload: completion)
      }
    }

    var payload: [String: Any] {
      var payload = request?.payload ?? WalkExchange.inactiveContext
      payload["phoneSteps"] = steps
      payload["phoneCompletion"] = completion?.payload
      payload["phoneUpdatedAt"] = updatedAt
      return payload
    }
  }

  struct Update: Codable, Equatable, Identifiable, Sendable {
    let request: Request
    let linked: Bool
    var steps = 0
    var finishedAt: Date?

    var id: UUID { request.id }

    init(request: Request, linked: Bool, steps: Int = 0, finishedAt: Date? = nil) {
      self.request = request
      self.linked = linked
      self.steps = steps
      self.finishedAt = finishedAt
    }

    init?(payload: [String: Any]) {
      guard let request = Request(payload: payload), let linked = payload["watchLinked"] as? Bool,
        let steps = payload["watchSteps"] as? Int, steps >= 0 else { return nil }
      self.init(request: request, linked: linked, steps: steps, finishedAt: payload["watchFinishedAt"] as? Date)
    }

    var payload: [String: Any] {
      var payload = request.payload
      payload["watchLinked"] = linked
      payload["watchSteps"] = steps
      payload["watchFinishedAt"] = finishedAt
      if linked && finishedAt != nil { payload["walkSteps"] = steps }
      return payload
    }

    func merging(_ other: Self) -> Self {
      guard id == other.id else { return self }
      // Both devices can count the same steps. Repeated and delayed reports may only advance progress.
      return Self(request: request, linked: linked, steps: max(steps, other.steps),
        finishedAt: finishedAt ?? other.finishedAt)
    }
  }
}
