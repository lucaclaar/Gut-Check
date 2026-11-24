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
      MascotView(name: linkedToPhone ? "MascotWorstCase4" : "MascotStillDoubtful1", width: 74, height: 64)

      // Walks only begin from the iPhone, so without one waiting there is nothing to start here.
      Text(linkedToPhone ? "Your walk is ready." : "Waiting for your walk")
        .font(GutTheme.display(14))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Text(linkedToPhone
        ? "Leave your iPhone behind."
        : "Start a Reflect walk on your iPhone and it will begin here.")
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(Color("GutMuted"))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      if linkedToPhone {
        Button(action: onStart) {
          Text("Start walk")
            .font(.system(.body, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(GutTheme.yellow)
        .foregroundStyle(GutTheme.ink)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 4)
  }
}

#Preview {
  StartWalkView(linkedToPhone: false, onStart: {})
}
