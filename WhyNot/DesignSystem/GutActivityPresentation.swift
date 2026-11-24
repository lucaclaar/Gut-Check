import SwiftUI

extension GutActivitySnapshot {
  var title: LocalizedStringKey { isWalk ? "Reflect walk" : "Turbo round" }

  var symbol: String {
    switch stage {
    case .walk: "figure.walk"
    case .turboPaused: "pause.fill"
    case .turboCountdown, .turboRound: "bolt.fill"
    }
  }

  var tint: Color { isWalk ? GutTheme.purple : GutTheme.yellow }

  var status: LocalizedStringKey {
    switch stage {
    case .walk: "In progress"
    case .turboCountdown: "Starting"
    case .turboRound: "Time left"
    case .turboPaused: "Paused"
    }
  }
}

struct GutActivityMetric: View {
  let snapshot: GutActivitySnapshot
  var steps: Int?
  var compact = false

  var body: some View {
    Group {
      switch snapshot.stage {
      case .walk:
        if let steps {
          let label: LocalizedStringKey = steps == 1 ? "1 step" : "\(steps.formatted()) steps"
          if compact {
            Text(steps, format: .number).accessibilityLabel(label)
          } else {
            Text(label)
          }
        } else {
          Text(timerInterval: snapshot.startedAt...max(snapshot.startedAt, snapshot.expiresAt),
            countsDown: false, showsHours: false)
        }
      case .turboCountdown(let deadline), .turboRound(let deadline):
        Text(timerInterval: min(snapshot.startedAt, deadline)...deadline, countsDown: true, showsHours: false)
      case .turboPaused(let secondsLeft):
        if compact {
          Text("\(secondsLeft)s").accessibilityLabel("\(secondsLeft) seconds remaining")
        } else {
          Text("\(secondsLeft) s left")
        }
      }
    }
    .monospacedDigit()
    .lineLimit(1)
    .minimumScaleFactor(0.7)
  }
}
