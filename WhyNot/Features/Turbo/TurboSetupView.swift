import SwiftUI

struct TurboSetupView: View {
  let session: TurboSession
  let start: () -> Void
  let showSafety: (SafetyConcern) -> Void
  @AppStorage("hasSeenTurboGuide") private var hasSeenGuide = false
  @State private var showsGuide = false
  @State private var speech = SpeechInput()
  @State private var dictatingID: UUID?
  @State private var lastShownConcern: SafetyConcern?
  @FocusState private var focusedOption: UUID?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    VStack(spacing: 0) {
      GeometryReader { geometry in
        let compact = focusedOption != nil && geometry.size.height < 410
        ScrollView {
          form(compact: compact)
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .padding(.top, compact ? 10 : 16)
            .padding(.bottom, compact ? 6 : 12)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .swipeActionsContainer()
      }

      startFooter
    }
    .background(GutBackground(origin: CGPoint(x: 172, y: 580)))
    .navigationTitle("Turbo").navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("How to play Turbo", systemImage: "questionmark") { showsGuide = true }
          .labelStyle(.iconOnly)
      }
    }
    .alert("How to play Turbo", isPresented: $showsGuide) {
      Button("Got it", role: .cancel) {}
    } message: {
      Text("Tap to refill a bubble. Hold to choose it. Flick to discard it. The rings show how long each bubble has left.")
    }
    .onChange(of: session.duplicateOptionIDs.isEmpty) { _, noDuplicates in
      if !noDuplicates {
        AccessibilityNotification.Announcement("Give each option a different name.").post()
      }
    }
    .onChange(of: speech.transcript) { _, text in
      guard !text.isEmpty, let id = dictatingID else { return }
      session.setOptionText(text, for: id)
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
    .onChange(of: scenePhase) { _, phase in if phase == .background { speech.stop() } }
    .alert("Voice input unavailable", isPresented: $speech.showError) {
    } message: { Text(speech.errorMessage) }
  }

  private func form(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("What do you want to decide?")
        .font(GutTheme.display(compact ? 23 : 28))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if !compact {
        Text("Enter your options")
          .font(.headline)
          .padding(.top, 12)
      }

      VStack(spacing: compact ? 8 : 12) {
        ForEach(Array(session.options.enumerated()), id: \.element.id) { index, option in
          optionRow(option, number: index + 1)
        }
      }
      .padding(.top, compact ? 14 : 20)

      HStack(spacing: 10) {
        Button { focusedOption = session.addOption() } label: {
          Label("Add option", systemImage: "plus").font(.body.weight(.medium))
        }
        .buttonStyle(.glass).controlSize(.large).buttonBorderShape(.capsule)
        .disabled(session.options.count >= 6 && session.filledOptions.count >= 6)

        Spacer(minLength: 0)

        Button(speech.isListening ? "Stop dictation" : "Dictate an option",
          systemImage: "microphone.fill", action: toggleSpeech)
          .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.large).buttonBorderShape(.circle)
          .tint(speech.isListening ? GutTheme.orange : .white)
          .disabled(speech.isPreparing || (!speech.isListening && focusedOption == nil && session.filledOptions.count >= 6))
          .accessibilityHint("Select an option field to replace it with dictation, or dictate into an empty option.")
      }
      .padding(.top, compact ? 12 : 16)

      if focusedOption == nil {
        if !hasSeenGuide {
          Text("Tap to refill a bubble. Hold to choose it. Flick to discard it.")
            .font(.footnote).foregroundStyle(GutTheme.muted).padding(.top, 18)
        }

        MascotView(name: "MascotWorstCase3", width: 144, height: 115)
          .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 22)
      }
    }
  }

  private var startFooter: some View {
    VStack(spacing: 8) {
      if let message = session.validationMessage {
        Text(message)
          .font(.footnote)
          .multilineTextAlignment(.center)
          .foregroundStyle(session.duplicateOptionIDs.isEmpty ? GutTheme.muted : GutTheme.orange)
      }
      GutButton(title: "Start") {
        speech.stop()
        focusedOption = nil
        if let concern = session.safetyConcern {
          showSafety(concern)
        } else {
          hasSeenGuide = true
          start()
        }
      }
      .disabled(!session.canStart || speech.isListening || speech.isPreparing)
      .accessibilityIdentifier("turbo.start")
    }
    .frame(maxWidth: 500)
    .padding(.horizontal, 24)
    .padding(.top, 8)
    .padding(.bottom, focusedOption == nil ? 20 : 8)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func optionRow(_ option: TurboOption, number: Int) -> some View {
    let row = optionField(option, number: number)
    if session.options.count > 3 {
      row.swipeActions(edge: .trailing, allowsFullSwipe: false, content: {
        Button("Remove", systemImage: "minus.circle", role: .destructive) {
          remove(option.id)
        }
      }, onPresentationChanged: { _ in })
    } else {
      row
    }
  }

  private func optionField(_ option: TurboOption, number: Int) -> some View {
    let isDuplicate = session.duplicateOptionIDs.contains(option.id)
    let isRecording = speech.isListening && dictatingID == option.id
    let canRemoveRow = session.options.count > 3
    let canClear = !option.text.isEmpty || (dictatingID == option.id && (isRecording || speech.isPreparing))
    let showsRemoval = canRemoveRow || canClear

    // The system can finish editing after a row has left the collection.
    let text = Binding(
      get: { session.optionText(for: option.id) },
      set: { session.setOptionText($0, for: option.id) }
    )

    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        TextField("Option \(number)", text: text,
          prompt: Text("Option \(number)").foregroundStyle(GutTheme.muted))
          .focused($focusedOption, equals: option.id)
          .submitLabel(number < session.options.count ? .next : .done)
          .onSubmit { advance(after: option.id) }
          .disabled(isRecording || (speech.isPreparing && dictatingID == option.id))
          .accessibilityLabel("Option \(number)")
          .accessibilityHint(isDuplicate ? "This option duplicates another one." : "")
          .padding(.leading, 16)
          .padding(.trailing, showsRemoval ? 0 : 16)
          .frame(minHeight: 52)

        if showsRemoval {
          Button(canRemoveRow ? "Delete option \(number)" : "Clear option \(number)",
            systemImage: canRemoveRow ? "minus.circle.fill" : "xmark.circle.fill") {
            remove(option.id)
          }
          .labelStyle(.iconOnly)
          .foregroundStyle(canRemoveRow ? GutTheme.orange : GutTheme.muted)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
          .buttonStyle(.plain)
        }
      }

      if isRecording {
        ListeningWaveform(waveform: speech.waveform)
          .frame(height: 40).padding(.horizontal, 16).padding(.bottom, 8)
      }
    }
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(isDuplicate || isRecording ? GutTheme.orange : .white.opacity(0.18))
        .allowsHitTesting(false)
    }
    .contentShape(.rect(cornerRadius: 16))
  }

  private func advance(after id: UUID) {
    guard let index = session.options.firstIndex(where: { $0.id == id }) else { return }
    let next = session.options.index(after: index)
    focusedOption = session.options.indices.contains(next) ? session.options[next].id : nil
  }

  private func remove(_ id: UUID) {
    if focusedOption == id, session.options.count > 3,
      let index = session.options.firstIndex(where: { $0.id == id }) {
      let next = index + 1 < session.options.count ? index + 1 : index - 1
      focusedOption = session.options[next].id
    }
    if dictatingID == id {
      dictatingID = nil
      speech.stop()
    }
    session.removeOption(id)
  }

  private func toggleSpeech() {
    if speech.isListening {
      speech.finish()
      return
    }
    dictatingID = focusedOption ?? session.addOption()
    guard dictatingID != nil else { return }
    focusedOption = nil
    Task { await speech.start() }
  }
}
