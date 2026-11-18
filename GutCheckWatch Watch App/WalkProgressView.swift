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
      ZStack {
        Circle()
          .stroke(Color("WatchRing").opacity(0.25), lineWidth: 10)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(Color("WatchRing"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
          .rotationEffect(.degrees(-90))

        VStack(spacing: 0) {
          Text(steps, format: .number)
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
          Text("of \(goal.formatted())")
            .font(.caption2)
            .foregroundStyle(Color("WatchPeriwinkle"))
        }
      }
      .frame(width: 104, height: 104)
      .padding(5)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: steps)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Walk progress")
      .accessibilityValue("\(steps.formatted()) of \(goal.formatted()) steps")

      if let issue {
        Text(issue)
          .font(.caption2)
          .foregroundStyle(Color("WatchSubtitle"))
          .multilineTextAlignment(.center)
      }

      Button("End walk", action: onEnd)
        .buttonStyle(.bordered)
    }
  }
}

#Preview {
  WalkProgressView(steps: 820, goal: WalkExchange.goal, issue: nil, onEnd: {})
}
