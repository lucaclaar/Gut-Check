import CoreMotion
import Observation

@MainActor @Observable
final class WalkTracker {
  private(set) var steps = 0
  private(set) var issue: String?
  var status: String { issue ?? "Counting your steps" }
  @ObservationIgnored private var pedometer: CMPedometer?
  @ObservationIgnored private var startedAt: Date?
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private var isRunning = false
  func start(from date: Date = .now) {
    guard !isRunning else { return }
    #if targetEnvironment(simulator)
      issue = "Step counting isn't available in the simulator."
    #else
      guard CMPedometer.isStepCountingAvailable() else {
        issue = "Step counting isn't available on this device."
        return
      }
      guard CMPedometer.authorizationStatus() != .denied,
        CMPedometer.authorizationStatus() != .restricted
      else {
        issue = "Allow Motion & Fitness in Settings to count your steps."
        return
      }
      let pedometer = pedometer ?? CMPedometer()
      self.pedometer = pedometer
      issue = nil
      let startedAt = startedAt ?? date
      self.startedAt = startedAt
      generation += 1
      let operation = generation
      isRunning = true
      pedometer.startUpdates(from: startedAt) { @Sendable [weak self] data, error in
        let count = data?.numberOfSteps.intValue
        let failed = error != nil
        Task { @MainActor [weak self] in
          guard let self, self.generation == operation, self.isRunning else { return }
          if let count { self.steps = count }
          if failed { self.issue = "Step counting is temporarily unavailable." }
        }
      }
    #endif
  }
  func stop() {
    generation += 1
    isRunning = false
    pedometer?.stopUpdates()
  }
}
