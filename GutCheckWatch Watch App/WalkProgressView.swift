//
//  WalkProgressView.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import SwiftUI

struct WalkProgressView: View {
  let steps: Int
  let goal: Int
  let issue: String?
  let onEnd: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var progress: Double { min(Double(steps) / Double(goal), 1) }

  var body: some View {
    VStack(spacing: 8) {
      // Same white ring on a dark track as the iPhone walk screen.
      ZStack {
        Circle()
          .stroke(Color("GutRingTrack"), lineWidth: 8)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))

        VStack(spacing: 0) {
          Text(steps, format: .number)
            .font(GutTheme.display(20))
            .monospacedDigit()
            .contentTransition(.numericText())
          Text("of \(goal.formatted())")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(Color("GutMuted"))
        }
      }
      .frame(width: 82, height: 82)
      .padding(4)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: steps)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Walk progress")
      .accessibilityValue("\(steps.formatted()) of \(goal.formatted()) steps")

      if let issue {
        Text(issue)
          .font(.system(size: 11, design: .rounded))
          .foregroundStyle(Color("GutMuted"))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button(action: onEnd) {
        Text("End walk")
          .font(.system(.body, design: .rounded).weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
  }
}

#Preview {
  WalkProgressView(steps: 820, goal: WalkExchange.goal, issue: nil, onEnd: {})
}
