import SwiftUI

struct ReflectionDeferredView: View {
  let session: ReflectionSession
  private let reminders = ReflectionReminder.shared

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        MascotView(name: "MascotMixedEmotions1", width: 192, height: 150)
          .frame(maxWidth: .infinity)
        Text("Sleep on it.")
          .font(GutTheme.display(30))
          .accessibilityAddTraits(.isHeader)
        Text(session.lastSaved?.question ?? session.question)
          .font(.title3.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        Text("Your reflection is saved in Waiting for you. Pick it up whenever you’re ready.")
          .foregroundStyle(GutTheme.muted)
        if let id = session.lastSaved?.id, let status = reminders.statuses[id] {
          Text(status.message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GutTheme.purple)
            .accessibilityAddTraits(.updatesFrequently)
        }
      }
      .frame(maxWidth: 500, alignment: .leading)
      .padding(24)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Back home", action: session.home)
        .frame(maxWidth: 500)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }
    .background(GutBackground(asset: "32-164-Glow", origin: CGPoint(x: -60, y: 60)))
    .toolbar(.hidden, for: .navigationBar)
  }
}
