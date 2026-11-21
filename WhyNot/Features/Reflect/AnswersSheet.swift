import SwiftUI

struct AnswersSheet: View {
  let answers: [ReflectionAnswer]
  var summary: String? = nil
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        if let summary {
          Section {
            Text(summary)
              .font(.body)
              .padding(.vertical, 6)
          }
        }
        if !answers.isEmpty {
          Section {
            ForEach(answers.enumerated(), id: \.element.id) { index, answer in
              HStack(alignment: .top, spacing: 16) {
                Text((index + 1).formatted()).font(GutTheme.display(14)).frame(
                  width: 30, height: 30
                )
                .background(answer.question.lens.color, in: .rect(cornerRadius: 10)).foregroundStyle(
                  GutTheme.ink)
                VStack(alignment: .leading, spacing: 8) {
                  Text(answer.question.eyebrow).font(.caption).foregroundStyle(GutTheme.muted)
                  Text(answer.question.text)
                }
                Spacer(minLength: 0)
                Text(answer.yes ? "Yes" : "No").fontWeight(.semibold)
              }
              .padding(.vertical, 8)
            }
          } header: {
            if summary != nil { Text("From your answers") }
          }
        }
      }
      .overlay {
        if answers.isEmpty && summary == nil {
          ContentUnavailableView(
            "No answers yet", systemImage: "rectangle.stack",
            description: Text("You can make your decision whenever you're ready."))
        }
      }
      .navigationTitle(summary == nil ? "Your answers" : "Why this?").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", systemImage: "checkmark") { dismiss() }
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
