import SwiftUI

struct SafetySupportView: View {
  let concern: SafetyConcern
  var directory: SafetyDirectory = .bundled
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @State private var callUnavailable = false

  private var country: String { SafetyDirectory.suggestedCountry(locale: locale) }
  private var contacts: [SafetyContact] { directory.contacts(for: country) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 7) {
            GutEyebrow(title: "HERE FOR YOU", color: GutTheme.safetyCoral)
            Text("Your safety\ncomes first.")
              .font(GutTheme.display(23)).fixedSize(horizontal: false, vertical: true)
              .accessibilityAddTraits(.isHeader)
          }
          Spacer(minLength: 0)
          Button("Close support", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
            .controlSize(.regular).frame(minWidth: 44, minHeight: 44)
        }
        Text(concern.message).font(.callout).foregroundStyle(GutTheme.muted)
          .fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 12) {
          if contacts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Local contacts unavailable").font(.headline)
              Text("We don’t yet have verified numbers for your device region. In immediate danger, contact local emergency services.")
                .font(.subheadline).foregroundStyle(GutTheme.muted)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
          } else {
            ForEach(contacts) { contact in
              SafetyContactCard(contact: contact, call: { call(contact) })
            }
          }
        }
        VStack(alignment: .leading, spacing: 7) {
          Label(country.isEmpty ? "Device region unavailable" : "Device region · \(SafetyDirectory.countryName(country))",
            systemImage: "globe").font(.caption)
          Text("If it feels safe, reach out to someone you trust.").font(.caption)
        }
        .foregroundStyle(GutTheme.muted).fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24)
      .frame(maxWidth: 500).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .font(.system(.body, design: .rounded)).tint(.white).preferredColorScheme(.dark)
    .background(GutTheme.background.ignoresSafeArea())
    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(contacts.count > 1 ? 550 : 420), .large])
    .presentationDragIndicator(.visible).presentationCornerRadius(28)
    .alert("Call unavailable", isPresented: $callUnavailable) {
    } message: {
      Text("Call the displayed number from a phone. Calls aren’t available in the simulator.")
    }
  }

  private func call(_ contact: SafetyContact) {
    // No automatic calls: only an explicit tap opens the system phone confirmation.
    openURL(contact.dialingURL) { accepted in
      if !accepted { callUnavailable = true }
    }
  }
}

#Preview {
  SafetySupportView(concern: .selfHarm)
}
