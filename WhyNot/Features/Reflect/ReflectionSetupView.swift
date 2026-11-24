import SwiftUI

struct ReflectionSetupView: View {
  private enum CloudChoice: String {
    case undecided, allowed, onDevice
  }

  @Bindable var session: ReflectionSession
  @AppStorage("reflect.cardCloudChoice") private var cloudChoice = CloudChoice.undecided
  @State private var speech = SpeechInput()
  @State private var heldSpeech: Task<Void, Never>?
  @State private var generator = AppleReflectionCardGenerator()
  @State private var showCloudChoice = false
  @State private var generateAfterCloudChoice = false
  @FocusState private var isDilemmaFocused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("What's on your mind?")
          .font(.system(.title, design: .rounded).weight(.bold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 30)
          .contentShape(.rect)
          .onTapGesture { isDilemmaFocused = false }
          .accessibilityAddTraits(.isHeader)
        ReflectionQuestionInput(
          text: $session.question, isListening: speech.isListening,
          isPreparing: speech.isPreparing, waveform: speech.waveform,
          isFocused: $isDilemmaFocused, toggleSpeech: toggleSpeech, holdSpeech: setSpeechHeld)
        GutEyebrow(title: "WHO SHOULD ASK YOU THE QUESTIONS?")
          .padding(.top, 42)
          .contentShape(.rect)
          .onTapGesture { isDilemmaFocused = false }
        HStack(alignment: .top, spacing: 6) {
          ForEach(ReflectionLens.allCases) { lens in
            LensTile(lens: lens, selected: session.lens == lens) { select(lens) }.frame(
              maxWidth: .infinity)
          }
        }
        .padding(.top, 96).padding(.bottom, 30)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 16).frame(maxWidth: .infinity)
      .background { keyboardDismissArea }
    }
    .background { keyboardDismissArea }
    .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Generate cards", action: start).disabled(
        !session.canStart || speech.isListening || speech.isPreparing || session.isPreparingCards
      )
      .padding(.horizontal, 24).padding(.bottom, 20)
    }
    .navigationTitle("Reflect").navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar).background(GutBackground(asset: "32-37-Glow"))
    .toolbar {
      if AppleReflectionCardGenerator.cloudConfigured {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Card privacy", systemImage: "hand.raised") {
            isDilemmaFocused = false
            generateAfterCloudChoice = false
            showCloudChoice = true
          }.labelStyle(.iconOnly)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Help and support", systemImage: "heart.circle") {
          stopSpeech()
          session.safetyConcern = .support
        }.labelStyle(.iconOnly)
      }
    }
    .task { generator.prewarmDevice() }
    .task(id: session.question) {
      do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
      if session.checkSafety() {
        stopSpeech()
      } else if session.safetyConcern == nil, !session.isPreparingCards {
        generator.prewarmDevice(for: session.question)
      }
    }
    .onChange(of: session.safetyConcern) { _, concern in
      if concern != nil {
        isDilemmaFocused = false
        stopSpeech()
      }
    }
    .onDisappear(perform: stopSpeech)
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        stopSpeech()
        showCloudChoice = false
      }
    }
    .confirmationDialog("Use Apple’s Private Cloud Compute?", isPresented: $showCloudChoice,
      titleVisibility: .visible
    ) {
      Button("Allow Apple’s cloud") { chooseCloud(.allowed) }
      Button("Use on-device AI") { chooseCloud(.onDevice) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Gut Check sends your dilemma and selected lens to Apple to prepare your cards. You can change this in Card privacy.")
    }
    .alert("Voice input unavailable", isPresented: $speech.showError) {
    } message: {
      Text(speech.errorMessage)
    }
  }
  private var keyboardDismissArea: some View {
    Color.clear
      .contentShape(.rect)
      .onTapGesture { isDilemmaFocused = false }
      .accessibilityHidden(true)
  }

  private func select(_ lens: ReflectionLens) {
    isDilemmaFocused = false
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { session.lens = lens }
  }
  private func start() {
    let startedAt = ContinuousClock.now
    isDilemmaFocused = false
    stopSpeech()
    if cloudChoice == .undecided, generator.isCloudAvailable {
      guard session.safetyConcern == nil, !session.checkSafety(automatically: false) else { return }
      generateAfterCloudChoice = true
      showCloudChoice = true
    } else {
      generateCards(startedAt: startedAt)
    }
  }
  private func chooseCloud(_ choice: CloudChoice) {
    cloudChoice = choice
    if generateAfterCloudChoice { generateCards(startedAt: .now) }
    generateAfterCloudChoice = false
  }
  private func generateCards(startedAt: ContinuousClock.Instant) {
    session.shuffle(using: generator, preferCloud: cloudChoice == .allowed, startedAt: startedAt)
  }
  private func toggleSpeech() {
    guard heldSpeech == nil else { return }
    if speech.isListening { speech.finish() } else { Task { await startSpeech() } }
  }

  private func startSpeech() async {
    let existingQuestion = session.question
    let separator = existingQuestion.isEmpty || existingQuestion.last?.isWhitespace == true ? "" : " "
    await speech.start { [session] transcript in
      let addition = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !addition.isEmpty else { return }
      // Each result contains the full current recording, including any revised words.
      session.question = existingQuestion + separator + addition
    }
  }

  private func setSpeechHeld(_ held: Bool) {
    if held {
      guard heldSpeech == nil, !speech.isListening, !speech.isPreparing else { return }
      heldSpeech = Task {
        guard !Task.isCancelled else { return }
        await startSpeech()
      }
    } else if let heldSpeech {
      heldSpeech.cancel()
      self.heldSpeech = nil
      if speech.isListening { speech.finish() }
      else if speech.isPreparing { speech.stop() }
    }
  }

  private func stopSpeech() {
    heldSpeech?.cancel()
    heldSpeech = nil
    speech.stop()
  }
}
