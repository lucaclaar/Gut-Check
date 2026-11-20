import SwiftUI

struct HomeHelpView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          mode("Reflect", color: GutTheme.purple,
            detail: "Work through a few questions and notice how you feel about your options.")
          Divider().accessibilityHidden(true)
          mode("Turbo", color: GutTheme.yellow,
            detail: "Add a few options, then follow your first reaction in a timed round.")
        }
        .frame(maxWidth: 450, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
      }
      .background(GutBackground())
      .navigationTitle("How it works")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close guide", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("home.help.close")
        }
      }
    }
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private func mode(_ title: String, color: Color, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(GutTheme.display(20))
        .foregroundStyle(color)
        .accessibilityAddTraits(.isHeader)
      Text(detail)
        .font(.system(.body, design: .rounded))
        .foregroundStyle(GutTheme.muted)
    }
  }
}
