import SwiftUI

struct ReflectionSavedView: View {
  let session: ReflectionSession
  private let reminders = ReflectionReminder.shared

  private var saved: SavedDecision? { session.lastSaved }
  private var answers: [ReflectionAnswer] { saved?.answers ?? session.answers }
  private var walks: Int { saved?.walks ?? session.walks }
  private var rating: Double { saved?.feeling ?? session.feeling }
  private var reminderStatus: ReflectionReminder.Status? {
    guard let saved else { return nil }
    return reminders.statuses[saved.id]
  }
  private var feeling: String { ReflectionSession.feelingTitle(for: rating) }

  var body: some View {
    VStack(spacing: 0) {
      summary
      actions
    }
    .background(GutBackground(asset: "32-164-Glow", origin: CGPoint(x: -60, y: 60)))
    .toolbar(.hidden, for: .navigationBar)
    .onChange(of: reminderStatus) { _, status in
      if let status, status != .scheduling {
        AccessibilityNotification.Announcement(status.message).post()
      }
    }
  }

  private var summary: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        VStack(spacing: 16) {
          MascotView(name: ReflectionSession.feelingMascot(for: rating), width: 180, height: 158)
          Text(rating < 0.33 ? "Sleep on it." : rating < 0.66 ? "Decision saved." : "Decision made.")
            .font(GutTheme.display(30))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            GutEyebrow(title: "YOU DECIDED", color: GutTheme.purple)
              .accessibilityAddTraits(.isHeader)
            Text(saved?.decision ?? session.decision)
              .font(.system(.title2, design: .rounded).weight(.semibold))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.leading, 15)
          .overlay(alignment: .leading) {
            Capsule().fill(GutTheme.purple).frame(width: 3).accessibilityHidden(true)
          }

          Divider().accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 7) {
            GutEyebrow(title: "FEELING")
              .accessibilityAddTraits(.isHeader)
            Text(feeling)
              .font(.system(.headline, design: .rounded))
            Text("\(answers.count(where: \.yes)) of \(answers.count) yes · \(walks) \(walks == 1 ? "walk" : "walks")")
              .font(.subheadline)
              .foregroundStyle(GutTheme.muted)
          }
        }

        Text("Your answers helped you explore. The choice was yours.")
          .font(.footnote)
          .foregroundStyle(GutTheme.muted)
      }
      .frame(maxWidth: 500)
      .padding(.horizontal, 24)
      .padding(.top, 38)
      .padding(.bottom, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
  }

  private var actions: some View {
    VStack(spacing: 10) {
      if let reminderStatus {
        Text(reminderStatus.message)
          .font(.footnote)
          .foregroundStyle(GutTheme.muted)
          .multilineTextAlignment(.center)
      }

      GutButton(title: "Back home", action: session.home)
    }
    .frame(maxWidth: 500)
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .padding(.bottom, 20)
    .frame(maxWidth: .infinity)
  }
}
