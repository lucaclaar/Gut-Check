//
//  StartWalkView.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import SwiftUI

struct StartWalkView: View {
    let onStart: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
             MascotView(name: "MascotWorstCase4", width: 74, height: 64)
               .frame(maxWidth: .infinity)

             Text("Gut Check")
               .font(.caption2)
               .foregroundStyle(Color("WatchPeriwinkle"))

             Text("Lots of what-ifs. Time for a 2,000-step walk?")
               .font(.footnote.weight(.semibold))
               .foregroundStyle(.white)
               .fixedSize(horizontal: false, vertical: true)

             Spacer(minLength: 8)

             Button(action: onStart) {
               Text("Start walk")
                 .font(.footnote.weight(.semibold))
                 .foregroundStyle(GutTheme.ink)
                 .frame(maxWidth: .infinity)
                 .padding(.vertical, 10)
                 .background(GutTheme.yellow, in: Capsule())
             }
             .buttonStyle(.plain)
        }
    }
}

#Preview {
    StartWalkView(onStart: {})
}
