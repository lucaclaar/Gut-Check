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

     /// 0.0 = no steps, 1.0 = goal reached. min(...) stops it going past full.
     private var progress: Double { min(Double(steps) / Double(goal), 1) }
    var body: some View {
        VStack(spacing: 10) {
              ZStack {
                // Background track
                Circle()
                  .stroke(Color("WatchRing").opacity(0.25), lineWidth: 12)
                // Progress part
                Circle()
                  .trim(from: 0, to: progress)
                  .stroke(Color("WatchRing"), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                  .rotationEffect(.degrees(-90))  // start at the top, not on the right

                VStack(spacing: 0) {
                  Text(steps, format: .number)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())  // digits roll when they change
                  Text("/ \(goal.formatted())")
                    .font(.caption2)
                    .foregroundStyle(Color("WatchPeriwinkle"))
                }
              }
              .frame(width: 112, height: 112)
              .animation(.default, value: steps)

              Text("Keep going, your buddy is cheering")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            }
          }
    }

#Preview {
    WalkProgressView(steps: 820, goal: 2_000)
}
