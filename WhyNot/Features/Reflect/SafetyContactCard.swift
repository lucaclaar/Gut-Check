import SwiftUI

struct SafetyContactCard: View {
  let contact: SafetyContact
  let call: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    if contact.isEmergency { emergencyButton }
    else { supportContact }
  }

  private var emergencyButton: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
      : AnyLayout(HStackLayout(spacing: 12))

    return Button(action: call) {
      layout {
        VStack(alignment: .leading, spacing: 3) {
          Text("Emergency help").font(.headline)
          Text(contact.hours ?? "For immediate danger")
            .font(.footnote).foregroundStyle(GutTheme.ink.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Label("Call \(contact.phone)", systemImage: "phone.fill")
          .font(.headline)
          .monospacedDigit()
          .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
      }
      .multilineTextAlignment(.leading)
      .foregroundStyle(GutTheme.ink)
      .padding(.horizontal, 4)
      .padding(.vertical, 9)
      .frame(minHeight: 54)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.roundedRectangle(radius: 20))
    .controlSize(.regular)
    .tint(GutTheme.safetyCoral)
    .accessibilityLabel("Emergency help. Call \(contact.phone)")
    .accessibilityHint(contact.hours ?? "For immediate danger")
  }

  private var supportContact: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
      : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

    return VStack(alignment: .leading, spacing: 0) {
      layout {
        VStack(alignment: .leading, spacing: 5) {
          Text(contact.name)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
          Text(contact.phone)
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .textSelection(.enabled)
          Text(contact.hours ?? "Hours not confirmed")
            .font(.footnote)
            .foregroundStyle(GutTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button("Call", systemImage: "phone.fill", action: call)
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.glass)
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          .accessibilityLabel("Call \(contact.name), \(contact.phone)")
      }

      Link(destination: contact.website) {
        Label("Hours & info", systemImage: "arrow.up.right")
          .font(.footnote.weight(.medium))
          .frame(minHeight: 44, alignment: .leading)
      }
      .foregroundStyle(GutTheme.purple)
    }
    .padding(.horizontal, 16)
    .padding(.top, 15)
    .padding(.bottom, 2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.white.opacity(0.055), in: .rect(cornerRadius: 20))
    .fixedSize(horizontal: false, vertical: true)
  }
}
