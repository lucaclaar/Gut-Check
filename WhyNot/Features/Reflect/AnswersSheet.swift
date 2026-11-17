import SwiftUI

struct AnswersSheet: View {
  let answers: [ReflectionAnswer]
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        ForEach(answers) { answer in
          HStack(alignment: .top, spacing: 16) {
            Text(answer.question.id.formatted()).font(GutTheme.display(14)).frame(
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
      }
      .overlay {
        if answers.isEmpty {
          ContentUnavailableView(
            "No answers yet", systemImage: "rectangle.stack",
            description: Text("You can make your decision whenever you're ready."))
        }
      }
      .navigationTitle("Your answers").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", systemImage: "checkmark") { dismiss() }
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
