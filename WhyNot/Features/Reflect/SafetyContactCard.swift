import SwiftUI

struct SafetyContactCard: View {
  let contact: SafetyContact
  let call: () -> Void

  private var foreground: Color { contact.isEmergency ? GutTheme.ink : .white }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(contact.isEmergency ? "IN CASO DI EMERGENZA" : "PER PARLARE CON QUALCUNO",
        systemImage: contact.isEmergency ? "cross.case" : "bubble.left.and.bubble.right")
        .font(.caption.weight(.semibold)).tracking(1)
      VStack(alignment: .leading, spacing: 6) {
        Text(contact.name).font(.headline).accessibilityAddTraits(.isHeader)
        Text(contact.phone)
          .font(.system(contact.isEmergency ? .largeTitle : .title2, design: .rounded).weight(.bold))
          .textSelection(.enabled)
        if contact.isEmergency {
          Text("Per un pericolo immediato o un’emergenza medica.").font(.subheadline)
        } else {
          Text("Un servizio di ascolto. Per un pericolo immediato, chiama i soccorsi.")
            .font(.subheadline)
        }
      }
      if let hours = contact.hours {
        Label(hours, systemImage: "clock").font(.footnote)
      } else if !contact.isEmergency {
        Label("Orari non verificati: consulta il sito", systemImage: "clock").font(.footnote)
      }
      Button(action: call) {
        Label("Chiama \(contact.phone)", systemImage: "phone.fill")
          .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 28)
      }
      .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
      .tint(contact.isEmergency ? GutTheme.ink : Color.white)
      .foregroundStyle(contact.isEmergency ? Color.white : GutTheme.ink)
      Link(destination: contact.website) {
        Label(contact.isEmergency ? "Fonte e informazioni" : "Sito e orari del servizio",
          systemImage: "arrow.up.right").font(.footnote.weight(.medium))
          .frame(minHeight: 32)
      }.foregroundStyle(foreground)
    }
    .foregroundStyle(foreground).padding(20).frame(maxWidth: .infinity, alignment: .leading)
    .background(contact.isEmergency ? Color(red: 0.86, green: 0.94, blue: 0.85) : .white.opacity(0.07),
      in: .rect(cornerRadius: 26))
    .fixedSize(horizontal: false, vertical: true)
  }
}
