//
//  WalkDoneView.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import SwiftUI

struct WalkDoneView: View {
  let linkedToPhone: Bool
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      MascotView(name: "MascotBestCase2", width: 86, height: 76)

      Text("Walk done!")
        .font(GutTheme.display(16))

      if linkedToPhone {
        Text("Open Gut Check on your iPhone to continue.")
          .font(.system(.caption2, design: .rounded))
          .foregroundStyle(Color("GutMuted"))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button(action: onDone) {
        Text("Done")
          .font(.system(.body, design: .rounded).weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(GutTheme.yellow)
      .foregroundStyle(GutTheme.ink)
    }
  }
}

#Preview {
  WalkDoneView(linkedToPhone: true, onDone: {})
}
