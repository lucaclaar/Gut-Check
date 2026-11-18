import SwiftUI

struct SafetyContactCard: View {
  let contact: SafetyContact
  let call: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: contact.isEmergency ? 14 : 4) {
      if contact.isEmergency {
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 5) {
            Text("Emergency help").font(.headline).accessibilityAddTraits(.isHeader)
            if let hours = contact.hours {
              Label(hours, systemImage: "clock").font(.caption).foregroundStyle(GutTheme.muted)
            } else {
              Text("For immediate danger").font(.caption).foregroundStyle(GutTheme.muted)
            }
          }
          Spacer(minLength: 8)
          Text(contact.phone).font(GutTheme.display(28)).foregroundStyle(GutTheme.safetyCoral)
        }
        Button(action: call) {
          Label("Call \(contact.phone)", systemImage: "phone.fill")
            .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.glassProminent).buttonBorderShape(.capsule).controlSize(.large)
        .tint(GutTheme.safetyCoral).foregroundStyle(GutTheme.ink)
      } else {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(contact.name).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(contact.hours ?? "Hours not confirmed")
              .font(.caption).foregroundStyle(GutTheme.muted)
          }
          Spacer(minLength: 0)
          Button("Call", systemImage: "phone.fill", action: call)
            .font(.subheadline.weight(.semibold)).buttonStyle(.glass).buttonBorderShape(.capsule)
            .controlSize(.regular).accessibilityLabel("Call \(contact.name), \(contact.phone)")
        }
        HStack(spacing: 12) {
          Text(contact.phone).font(.subheadline).foregroundStyle(GutTheme.muted).textSelection(.enabled)
          Spacer(minLength: 0)
          Link(destination: contact.website) {
            Label("Hours & info", systemImage: "arrow.up.right").font(.caption)
              .frame(minHeight: 44)
          }.foregroundStyle(.white)
        }
      }
    }
    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
    .background(contact.isEmergency ? GutTheme.safetyCoral.opacity(0.07) : .white.opacity(0.05),
      in: .rect(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22).strokeBorder(
        contact.isEmergency ? GutTheme.safetyCoral.opacity(0.3) : .white.opacity(0.12))
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
