import SwiftUI

struct ReflectionQuestionInput: View {
  @Binding var text: String
  let isListening: Bool
  let isPreparing: Bool
  let waveform: WaveformHistory
  let toggleSpeech: () -> Void
  @FocusState private var isFocused: Bool

  private let signal = Color(red: 243 / 255, green: 94 / 255, blue: 62 / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isListening {
        Text(text.isEmpty ? "Say what's on your mind…" : text)
          .font(.system(.body, design: .rounded).scaled(by: 19.0 / 17))
          .lineLimit(1).truncationMode(.tail)
          .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
      } else {
        TextField("What are you trying to decide?", text: $text, axis: .vertical)
          .font(.system(.body, design: .rounded).scaled(by: 19.0 / 17))
          .lineLimit(1...4).frame(minHeight: 24, alignment: .topLeading)
          .focused($isFocused)
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
          Text("Starting microphone…").font(.footnote).foregroundStyle(GutTheme.muted)
        }
        Spacer(minLength: 0)
      }
      .frame(height: 50)
      .padding(.leading, 22).padding(.trailing, 80).padding(.bottom, 9)
    }
    .overlay(alignment: .bottomTrailing) {
      Group {
        if isListening {
          Button("Stop listening", systemImage: "microphone.fill", action: microphoneTapped)
            .labelStyle(.iconOnly).font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white).frame(width: 50, height: 50)
            .background(Color(red: 1, green: 0.18, blue: 0.18), in: .circle)
            .background { Circle().fill(signal.opacity(0.24)).frame(width: 66, height: 66) }
            .buttonStyle(.plain)
        } else {
          Button("Dictate your question", systemImage: "microphone.fill", action: microphoneTapped)
            .labelStyle(.iconOnly).buttonStyle(.glass).buttonBorderShape(.circle)
            .controlSize(.large).disabled(isPreparing)
            .frame(width: 50, height: 50)
        }
      }
      .padding(9)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .strokeBorder(
          isListening ? signal.opacity(0.9) : .white.opacity(0.18), lineWidth: isListening ? 2 : 1)
    }
    .onChange(of: isListening) { _, listening in if listening { isFocused = false } }
    .accessibilityValue(isListening ? "Recording" : "")
  }

  private func microphoneTapped() {
    isFocused = false
    toggleSpeech()
  }
}
