import SwiftUI

struct ReflectionQuestionInput: View {
  @Binding var text: String
  let isListening: Bool
  let isPreparing: Bool
  let waveform: WaveformHistory
  let isFocused: FocusState<Bool>.Binding
  let toggleSpeech: () -> Void
  let holdSpeech: (Bool) -> Void
  @GestureState private var microphoneHeld = false

  private let signal = Color(red: 243 / 255, green: 94 / 255, blue: 62 / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isListening {
        Text(text.isEmpty ? "Say what's on your mind…" : text)
          .font(.system(.body, design: .rounded).scaled(by: 19.0 / 17))
          .lineLimit(1).truncationMode(.tail)
          .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
      } else {
        TextField("Your dilemma", text: $text,
          prompt: Text("Describe your dilemma in one sentence").foregroundStyle(GutTheme.muted),
          axis: .vertical)
          .font(.system(.body, design: .rounded).scaled(by: 19.0 / 17))
          .accessibilityLabel("Your dilemma")
          .lineLimit(2...4).frame(minHeight: 24, alignment: .topLeading)
          .focused(isFocused)
          .disabled(isPreparing)
      }
    }
    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 76)
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    .overlay(alignment: .bottomLeading) {
      HStack(spacing: 8) {
        if isListening {
          ListeningWaveform(waveform: waveform)
        } else if isPreparing {
          ProgressView().controlSize(.small)
          Text("Processing audio…").font(.footnote).foregroundStyle(GutTheme.muted)
        }
        Spacer(minLength: 0)
      }
      .frame(height: 50)
      .padding(.leading, 22).padding(.trailing, 80).padding(.bottom, 9)
    }
    .overlay(alignment: .bottomTrailing) {
      microphoneButton.padding(9)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .strokeBorder(
          isListening ? signal.opacity(0.9) : .white.opacity(0.18), lineWidth: isListening ? 2 : 1)
    }
    .onChange(of: isListening) { _, listening in if listening { isFocused.wrappedValue = false } }
    .accessibilityValue(isListening ? "Recording" : "")
  }

  private var microphoneButton: some View {
    Button(isListening ? "Stop listening" : "Dictate your question",
      systemImage: "microphone.fill", action: microphoneTapped)
      .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
      .controlSize(.large)
      .frame(width: 50, height: 50)
      .overlay {
        if isListening {
          Image(systemName: "microphone.fill")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white).frame(width: 50, height: 50)
            .background(Color(red: 1, green: 0.18, blue: 0.18), in: .circle)
            .background { Circle().fill(signal.opacity(0.24)).frame(width: 66, height: 66) }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
      }
      .contentShape(.circle)
      .highPriorityGesture(microphoneGesture)
      .onChange(of: microphoneHeld) { _, held in
        if held { isFocused.wrappedValue = false }
        holdSpeech(held)
      }
      .disabled(isPreparing && !microphoneHeld)
      .accessibilityHint(isListening ? "" : "Tap to start or hold to talk")
  }

  private var microphoneGesture: some Gesture {
    LongPressGesture(minimumDuration: 0.25, maximumDistance: 18)
      .sequenced(before: DragGesture(minimumDistance: 0))
      .exclusively(before: TapGesture())
      .updating($microphoneHeld) { value, held, _ in
        if case .first(.second(true, _)) = value { held = true }
      }
      .onEnded { value in
        if case .second = value { microphoneTapped() }
      }
  }

  private func microphoneTapped() {
    isFocused.wrappedValue = false
    toggleSpeech()
  }
}
