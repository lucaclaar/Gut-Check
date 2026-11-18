//
//  WalkDoneView.swift
//  GutCheckWatch Watch App
//
//  Created by Andréa LAURENT on 18/11/2026.
//

import SwiftUI

struct WalkDoneView: View {
    var body: some View {
        VStack(spacing: 6) {
           MascotView(name: "MascotBestCase2", width: 86, height: 76)

           Text("Walk done!")
             .font(.system(.title3, design: .rounded).weight(.black))
             .foregroundStyle(.white)

           Text("Open Gut Check on your iPhone to continue.")
             .font(.caption2)
             .foregroundStyle(Color("WatchSubtitle"))
             .multilineTextAlignment(.center)
         }
    }
}

#Preview {
    WalkDoneView()
}
