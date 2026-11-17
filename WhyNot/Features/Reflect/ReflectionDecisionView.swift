import SwiftUI

struct ReflectionDecisionView: View {
  @Bindable var session: ReflectionSession
  @State private var showAnswers = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("What did you decide?").font(GutTheme.display()).tracking(-0.54)
          .lineLimit(1).minimumScaleFactor(0.9).padding(.bottom, 16)
        Button {
          showAnswers = true
        } label: {
          HStack(spacing: 8) {
            Text("Your gut said").foregroundStyle(GutTheme.muted)
            Text("\(session.yesCount) yes · \(session.noCount) no").fontWeight(.semibold)
            Spacer(minLength: 0)
            AnswerDots(answers: session.answers)
            Image(systemName: "chevron.down").foregroundStyle(GutTheme.muted)
          }
          .font(.subheadline).padding(.horizontal, 14).padding(.vertical, 12)
          .frame(maxWidth: .infinity, minHeight: 44)
          .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
          .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)) }
        }
        .buttonStyle(.plain).accessibilityHint("Review your answers")
        GutTextInput(prompt: "Write down your decision", text: $session.decision).padding(.top, 12)
        GutEyebrow(title: "HOW DO YOU FEEL ABOUT IT?").padding(.top, 22)
        MascotView(
          name: session.feelingMascot,
          width: session.feeling >= 0.66 ? 147 : 178,
          height: session.feeling >= 0.66 ? 113 : 137
        )
        .frame(maxWidth: .infinity).padding(.top, session.feeling >= 0.66 ? 30 : 7)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: session.feelingMascot)
        Text(session.feelingTitle).font(GutTheme.display(19)).frame(maxWidth: .infinity).padding(
          .top, 8)
        Slider(value: $session.feeling, in: 0...1).tint(.blue)
          .accessibilityLabel("How do you feel about your decision?").accessibilityValue(
            session.feelingTitle
          )
          .frame(height: 52).padding(.top, 14).padding(.horizontal, 16)
        HStack {
          Text("Bad")
          Spacer()
          Text("Relieved")
        }
        .font(.footnote).foregroundStyle(GutTheme.muted).padding(.horizontal, 16).padding(.top, 3)
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 40).frame(
        maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      GutButton(title: "Save my decision", action: session.saveDecision).disabled(!session.canSave)
        .padding(.horizontal, 24).padding(.bottom, 20)
    }
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .background(GutBackground(asset: "32-143-Glow"))
    .sheet(isPresented: $showAnswers) {
      AnswersSheet(answers: session.answers).presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
  }
}
