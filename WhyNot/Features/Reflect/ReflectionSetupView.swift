import SwiftUI

struct ReflectionSetupView: View {
  @Bindable var session: ReflectionSession
  @State private var speech = SpeechInput()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("What's on your mind?").font(.system(.title, design: .rounded).weight(.bold)).padding(
          .bottom, 30)
        ReflectionQuestionInput(
          text: $session.question, isListening: speech.isListening,
          isPreparing: speech.isPreparing, waveform: speech.waveform, toggleSpeech: toggleSpeech)
        GutEyebrow(title: "CHOOSE A LENS").padding(.top, 42)
        HStack(alignment: .top, spacing: 6) {
          ForEach(ReflectionLens.allCases) { lens in
            LensTile(lens: lens, selected: session.lens == lens) { select(lens) }.frame(
              maxWidth: .infinity)
          }
        }
        .padding(.top, 96).padding(.bottom, 30)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 16).frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Shuffle the cards", action: start).disabled(
        !session.canStart || speech.isListening || speech.isPreparing
      )
      .padding(.horizontal, 24).padding(.bottom, 20)
    }
    .navigationTitle("Reflect").navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar).background(GutBackground(asset: "32-37-Glow"))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Aiuto e contatti", systemImage: "heart.circle") {
          speech.stop()
          session.safetyConcern = .support
        }.labelStyle(.iconOnly)
      }
    }
    .onChange(of: speech.transcript) { _, value in if !value.isEmpty { session.question = value } }
    .task(id: session.question) {
      do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
      if session.checkSafety() { speech.stop() }
    }
    .onChange(of: session.safetyConcern) { _, concern in
      if concern != nil { speech.stop() }
    }
    .onDisappear(perform: speech.stop)
    .onChange(of: scenePhase) { _, phase in if phase == .background { speech.stop() } }
    .alert("Voice input unavailable", isPresented: $speech.showError) {
    } message: {
      Text(speech.errorMessage)
    }
  }
  private func select(_ lens: ReflectionLens) {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { session.lens = lens }
  }
  private func start() {
    speech.stop()
    session.shuffle()
  }
  private func toggleSpeech() {
    if speech.isListening { speech.stop() } else { Task { await speech.start() } }
  }
}
