import SwiftUI

struct TurboSetupView: View {
  @Bindable var session: TurboSession
  let start: () -> Void
  let showSafety: (SafetyConcern) -> Void
  @State private var speech = SpeechInput()
  @State private var dictatingID: UUID?
  @State private var lastShownConcern: SafetyConcern?
  @FocusState private var focusedOption: UUID?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("What are your\noptions?").font(GutTheme.display(28))
          .fixedSize(horizontal: false, vertical: true).padding(.bottom, 28)
        VStack(spacing: 12) {
          ForEach($session.options) { $option in
            HStack(spacing: 14) {
              Text("\((session.options.firstIndex { $0.id == option.id } ?? 0) + 1)")
                .foregroundStyle(GutTheme.muted).accessibilityHidden(true)
              TextField("Add an option…", text: $option.text, axis: .vertical)
                .lineLimit(1...2).focused($focusedOption, equals: option.id)
                .accessibilityLabel("Option \((session.options.firstIndex { $0.id == option.id } ?? 0) + 1)")
              if session.options.count > 3 {
                Button("Remove option", systemImage: "xmark") { session.removeOption(option.id) }
                  .labelStyle(.iconOnly).font(.caption).foregroundStyle(GutTheme.muted)
                  .frame(minWidth: 28, minHeight: 36)
              }
            }
            .font(.system(.body, design: .rounded)).padding(.horizontal, 16).padding(.vertical, 8)
            .frame(minHeight: 52)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)) }
            .accessibilityIdentifier("turbo.option.\(option.id)")
          }
        }
        HStack(spacing: 10) {
          Button { focusedOption = session.addOption() } label: {
            Label("Add option", systemImage: "plus").font(.body.weight(.medium))
          }
          .buttonStyle(.glass).controlSize(.large).buttonBorderShape(.capsule)
          .disabled(session.options.count >= 6 && session.filledOptions.count >= 6)
          Spacer(minLength: 0)
          Button(speech.isListening ? "Stop dictation" : "Dictate an option", systemImage: "microphone.fill", action: toggleSpeech)
            .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.large).buttonBorderShape(.circle)
            .tint(speech.isListening ? GutTheme.orange : .white)
            .disabled(speech.isPreparing || (!speech.isListening && focusedOption == nil && session.filledOptions.count >= 6))
            .accessibilityHint("Select an option field to replace it with dictation, or dictate into an empty option.")
        }.padding(.top, 18)
        if speech.isListening {
          ListeningWaveform(waveform: speech.waveform).padding(.top, 12)
        }
        Text(session.validationMessage ?? "3 to 6 options. A word or two each.")
          .font(.footnote).foregroundStyle(GutTheme.muted).padding(.top, 20)
        MascotView(name: "MascotWorstCase3", width: 180, height: 144)
          .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 28)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    .navigationTitle("Turbo").navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .background(GutBackground(origin: CGPoint(x: 172, y: 580)))
    .safeAreaInset(edge: .bottom) {
      GutButton(title: session.canStart ? "Start · \(session.plannedSeconds) seconds" : "Start") {
        speech.stop()
        focusedOption = nil
        if let concern = session.safetyConcern { showSafety(concern) } else { start() }
      }
      .disabled(!session.canStart || speech.isListening || speech.isPreparing)
      .accessibilityIdentifier("turbo.start")
      .padding(.horizontal, 24).padding(.bottom, 20)
    }
    .onChange(of: speech.transcript) { _, text in
      guard !text.isEmpty, let id = dictatingID,
        let index = session.options.firstIndex(where: { $0.id == id }) else { return }
      session.options[index].text = text
    }
    .task(id: session.screeningText) {
      do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
      guard let concern = session.safetyConcern else { lastShownConcern = nil; return }
      guard concern != lastShownConcern else { return }
      lastShownConcern = concern
      speech.stop()
      showSafety(concern)
    }
    .onDisappear(perform: speech.stop)
    .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop() } }
    .alert("Voice input unavailable", isPresented: $speech.showError) {
    } message: { Text(speech.errorMessage) }
  }

  private func toggleSpeech() {
    if speech.isListening { speech.stop(); return }
    dictatingID = focusedOption ?? session.addOption()
    guard dictatingID != nil else { return }
    focusedOption = nil
    Task { await speech.start() }
  }
}
