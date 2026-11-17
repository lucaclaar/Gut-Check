import SwiftUI

struct SafetySupportView: View {
  let concern: SafetyConcern
  var directory: SafetyDirectory = .bundled
  @AppStorage("safetyCountryOverride") private var countryOverride = ""
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var showCountries = false
  @State private var callUnavailable = false

  private let accent = Color(red: 0.76, green: 0.90, blue: 0.78)
  private var country: String {
    countryOverride.isEmpty ? SafetyDirectory.suggestedCountry() : countryOverride
  }
  private var contacts: [SafetyContact] { directory.contacts(for: country) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          introduction
          countryControl
          if contacts.isEmpty {
            ContentUnavailableView {
              Label("Contatti non ancora disponibili", systemImage: "globe")
            } description: {
              Text("Per questo paese non abbiamo ancora numeri verificati. In caso di pericolo, contatta i soccorsi locali o chiedi aiuto a una persona vicina.")
            } actions: {
              Button("Cambia paese") { showCountries = true }.buttonStyle(.bordered)
            }
          } else {
            VStack(spacing: 14) {
              ForEach(contacts) { contact in
                SafetyContactCard(contact: contact, call: { call(contact) })
              }
            }
          }
          Text("Se puoi farlo in sicurezza, contatta anche una persona di cui ti fidi.")
            .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          Button("Torna al tuo pensiero") { dismiss() }
            .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.glass).buttonBorderShape(.capsule)
        }
        .padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity)
      }
      .background {
        Color(red: 0.055, green: 0.07, blue: 0.065).ignoresSafeArea()
      }
      .navigationTitle("Uno spazio di aiuto").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Chiudi", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
        }
      }
    }
    .font(.system(.body, design: .rounded)).tint(accent).preferredColorScheme(.dark)
    .presentationDetents([.large]).presentationDragIndicator(.visible)
    .sheet(isPresented: $showCountries) {
      SafetyCountryPicker(selection: $countryOverride, directory: directory)
    }
    .alert("Chiamata non disponibile", isPresented: $callUnavailable) {
    } message: {
      Text("Puoi chiamare il numero mostrato da un telefono. Il simulatore non può effettuare chiamate.")
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "heart.text.clipboard")
        .font(.system(.largeTitle).weight(.light))
        .foregroundStyle(accent).padding(20)
        .background(accent.opacity(0.10), in: .rect(cornerRadius: 26))
        .accessibilityHidden(true)
      Text("La tua sicurezza,\nprima di tutto.")
        .font(GutTheme.display(25)).foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
      Text(concern.message).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 10)
  }

  private var countryControl: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button { showCountries = true } label: {
        HStack {
          Image(systemName: "globe.europe.africa")
          Text(country.isEmpty ? "Scegli un paese" : SafetyDirectory.countryName(country))
            .fontWeight(.semibold)
          Spacer(minLength: 8)
          Text("Cambia").font(.subheadline)
          Image(systemName: "chevron.down").font(.caption.weight(.bold))
        }.padding(16).frame(minHeight: 52)
          .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
      }.buttonStyle(.plain).accessibilityHint("Scegli il paese in cui ti trovi per vedere i contatti locali")
      Text(countryOverride.isEmpty
        ? "Paese dalle impostazioni. Se sei all’estero, cambialo qui."
        : "Paese scelto da te. Puoi cambiarlo quando viaggi.")
        .font(.caption).foregroundStyle(.secondary)
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
