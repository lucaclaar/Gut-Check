import SwiftUI

struct ReflectionSavedView: View {
  let session: ReflectionSession
  @State private var reminderStatus: String?
  @State private var isScheduling = false
  @State private var reminderScheduled = false

  private let reminders = ReflectionReminder.shared

  private var saved: SavedDecision? { session.lastSaved }
  private var answers: [ReflectionAnswer] { saved?.answers ?? session.answers }
  private var walks: Int { saved?.walks ?? session.walks }
  private var rating: Double { saved?.feeling ?? session.feeling }
  private var feeling: String { ReflectionSession.feelingTitle(for: rating) }

  var body: some View {
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

        if rating < 0.33, let saved {
          VStack(alignment: .leading, spacing: 9) {
            GutButton(title: reminderScheduled ? "Reminder set" : "Remind me tomorrow",
              prominent: false) {
              isScheduling = true
              Task { await scheduleReminder(for: saved.id) }
            }
            .disabled(isScheduling || reminderScheduled)
            Text(reminderStatus ?? "Come back to this decision tomorrow morning.")
              .font(.footnote)
              .foregroundStyle(GutTheme.muted)
          }
        }
      }
      .frame(maxWidth: 500)
      .padding(.horizontal, 24)
      .padding(.top, 38)
      .padding(.bottom, 24)
      .frame(maxWidth: .infinity)
    }
    .onChange(of: reminderStatus) { _, status in
      if let status { AccessibilityNotification.Announcement(status).post() }
    }
    .scrollIndicators(.hidden)
    .task(id: saved?.id) {
      guard let saved, rating < 0.33 else { return }
      if await reminders.isScheduled(for: saved.id) {
        reminderScheduled = true
        reminderStatus = "We’ll remind you tomorrow at 9:00 AM."
      }
    }
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

  private func scheduleReminder(for id: UUID) async {
    defer { isScheduling = false }
    do {
      let scheduled = try await reminders.scheduleTomorrow(for: id)
      guard session.savedDecisions.contains(where: { $0.id == id && $0.feeling < 0.33 }) else {
        reminders.cancel(for: id)
        return
      }
      reminderScheduled = scheduled
      reminderStatus = scheduled
        ? "We’ll remind you tomorrow at 9:00 AM."
        : "Turn on notifications for Gut Check in Settings to set a reminder."
    } catch {
      reminderStatus = "Couldn’t set the reminder. Try again."
    }
  }
}
