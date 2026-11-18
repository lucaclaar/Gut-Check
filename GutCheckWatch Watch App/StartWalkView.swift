//
//  StartWalkView.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import SwiftUI

struct StartWalkView: View {
  let linkedToPhone: Bool
  let onStart: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      MascotView(name: "MascotWorstCase4", width: 74, height: 64)

      Text("Gut Check")
        .font(.caption2)
        .foregroundStyle(Color("WatchPeriwinkle"))

      Text(linkedToPhone ? "Your iPhone walk is ready." : "Time for a \(WalkExchange.goal.formatted())-step walk?")
        .font(.footnote.weight(.semibold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: onStart) {
        Text("Start walk").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(GutTheme.yellow)
      .foregroundStyle(GutTheme.ink)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 4)
  }
}

#Preview {
  StartWalkView(linkedToPhone: false, onStart: {})
}
