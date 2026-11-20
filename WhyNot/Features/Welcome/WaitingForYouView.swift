import SwiftUI

struct WaitingForYouView: View {
  let session: ReflectionSession
  let turbo: TurboSession
  let delete: (RecentDecision) throws -> Void
  let resume: (RecentDecision) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var showDeleteError = false

  private var decisions: [RecentDecision] {
    RecentDecision.newestFirst(reflect: session.savedDecisions, turbo: turbo.savedDecisions)
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Text("Waiting for you")
          .font(GutTheme.display(23))
          .accessibilityAddTraits(.isHeader)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button("Close", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .buttonStyle(.glass)
          .buttonBorderShape(.circle)
          .controlSize(.large)
          .accessibilityIdentifier("home.waiting.close")
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)

      if decisions.isEmpty {
        ContentUnavailableView("No saved activities yet", systemImage: "tray")
          .frame(maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(decisions) { activity in
              RecentDecisionRow(decision: activity) { resume(activity) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false, content: {
                  Button(role: .destructive) {
                    remove(activity)
                  } label: {
                    Image(systemName: "trash")
                      .accessibilityLabel("Delete")
                  }
                }, onPresentationChanged: { _ in })

              if activity.id != decisions.last?.id {
                Divider().padding(.horizontal, 12).accessibilityHidden(true)
              }
            }
          }
          .background(.white.opacity(0.055), in: .rect(cornerRadius: 22))
          .clipShape(.rect(cornerRadius: 22))
          .padding(.horizontal, 24)
          .padding(.vertical, 8)
        }
        .swipeActionsContainer()
      }
    }
    .frame(maxWidth: 500)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(308), .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(
      LinearGradient(
        colors: [
          GutTheme.background.mix(with: GutTheme.purple, by: 0.12),
          GutTheme.background.mix(with: GutTheme.purple, by: 0.05),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    )
    .alert("Couldn’t delete the activity", isPresented: $showDeleteError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Try deleting it again.")
    }
  }

  private func remove(_ activity: RecentDecision) {
    do { try delete(activity) }
    catch { showDeleteError = true }
  }
}
