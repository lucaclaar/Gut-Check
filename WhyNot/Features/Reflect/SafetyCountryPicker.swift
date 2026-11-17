import SwiftUI

struct SafetyCountryPicker: View {
  @Binding var selection: String
  let directory: SafetyDirectory
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  private var countries: [String] {
    Locale.Region.isoRegions.map(\.identifier)
      .filter { $0.count == 2 }
      .filter { search.isEmpty || SafetyDirectory.countryName($0).localizedStandardContains(search)
        || $0.localizedStandardContains(search) }
      .sorted { SafetyDirectory.countryName($0).localizedStandardCompare(SafetyDirectory.countryName($1)) == .orderedAscending }
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button("Usa il paese delle impostazioni") { selection = ""; dismiss() }
        } footer: {
          Text("Nessun accesso alla posizione. Scegli il paese in cui ti trovi adesso; i contatti funzionano nel paese indicato.")
        }
        Section("Paesi e territori") {
          ForEach(countries, id: \.self) { code in
            Button {
              selection = code
              dismiss()
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Text(SafetyDirectory.countryName(code)).foregroundStyle(.primary)
                  Text(directory.contacts(for: code).isEmpty ? "Contatti non ancora disponibili" : "Contatti verificati")
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if code == (selection.isEmpty ? SafetyDirectory.suggestedCountry() : selection) {
                  Image(systemName: "checkmark").accessibilityLabel("Selezionato")
                }
              }.frame(minHeight: 44)
            }
          }
        }
      }
      .searchable(text: $search, prompt: "Cerca paese")
      .navigationTitle("Dove ti trovi?").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Chiudi", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
        }
      }
    }
  }
}
