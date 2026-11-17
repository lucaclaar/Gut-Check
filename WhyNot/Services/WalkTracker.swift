import CoreMotion
import Observation

@MainActor @Observable
final class WalkTracker {
  private(set) var steps = 0
  private(set) var status = "Counting with iPhone"
  @ObservationIgnored private var pedometer: CMPedometer?
  @ObservationIgnored private var startedAt: Date?
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private var isRunning = false
  func start() {
    guard !isRunning else { return }
    #if targetEnvironment(simulator)
      status =
        "Step counting isn't available in the simulator. You can end your walk whenever you're ready."
    #else
      guard CMPedometer.isStepCountingAvailable() else {
        status =
          "Step counting isn't available on this device. You can end your walk whenever you're ready."
        return
      }
      guard CMPedometer.authorizationStatus() != .denied,
        CMPedometer.authorizationStatus() != .restricted
      else {
        status = "Allow Motion & Fitness in Settings to count your steps."
        return
      }
      let pedometer = pedometer ?? CMPedometer()
      self.pedometer = pedometer
      let startedAt = startedAt ?? .now
      self.startedAt = startedAt
      generation += 1
      let operation = generation
      isRunning = true
      pedometer.startUpdates(from: startedAt) { @Sendable [weak self] data, error in
        let count = data?.numberOfSteps.intValue
        let message = error?.localizedDescription
        Task { @MainActor [weak self] in
          guard let self, self.generation == operation, self.isRunning else { return }
          if let count { self.steps = count }
          if let message { self.status = message }
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
