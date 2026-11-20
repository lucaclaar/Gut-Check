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
        introduction

        if contacts.isEmpty {
          VStack(alignment: .leading, spacing: 7) {
            Text("Local contacts unavailable").font(.headline)
            Text("We don’t yet have verified numbers for your device region. In immediate danger, contact local emergency services.")
              .font(.subheadline).foregroundStyle(GutTheme.muted)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white.opacity(0.06), in: .rect(cornerRadius: 20))
        } else {
          VStack(spacing: 10) {
            ForEach(contacts) { contact in
              SafetyContactCard(contact: contact, call: { call(contact) })
            }
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          Label(country.isEmpty ? "Device region unavailable" : "Device region · \(SafetyDirectory.countryName(country))",
            systemImage: "globe")
          Text("If it feels safe, reach out to someone you trust.")
        }
        .font(.footnote)
        .foregroundStyle(GutTheme.muted)
        .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: 460)
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 22)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollIndicators(.hidden)
    .font(.system(.body, design: .rounded))
    .tint(.white)
    .preferredColorScheme(.dark)
    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(contacts.count > 1 ? 498 : 405), .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(
      LinearGradient(colors: [GutTheme.background.mix(with: GutTheme.purple, by: 0.11), GutTheme.background],
        startPoint: .topLeading, endPoint: .bottomTrailing))
    .alert("Call unavailable", isPresented: $callUnavailable) {
    } message: {
      Text("Call the displayed number from a phone. Calls aren’t available in the simulator.")
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(GutTheme.safetyCoral)
          .frame(width: 32, height: 32)
          .background(GutTheme.safetyCoral.opacity(0.12), in: .circle)
          .accessibilityHidden(true)

        GutEyebrow(title: "HERE FOR YOU", color: GutTheme.safetyCoral)

        Button("Close support", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .buttonStyle(.glass)
          .buttonBorderShape(.circle)
          .controlSize(.large)
      }

      Text("Your safety comes first.")
        .font(GutTheme.display(24))
        .accessibilityAddTraits(.isHeader)
      Text(concern.message)
        .font(.callout)
        .foregroundStyle(GutTheme.muted)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func call(_ contact: SafetyContact) {
    openURL(contact.dialingURL) { accepted in
      if !accepted { callUnavailable = true }
    }
  }
}

#Preview {
  SafetySupportView(concern: .selfHarm)
}
