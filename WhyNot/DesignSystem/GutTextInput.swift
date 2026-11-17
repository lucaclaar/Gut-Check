import SwiftUI

struct GutTextInput: View {
  let prompt: String
  @Binding var text: String
  var minHeight: Double = 88
  var body: some View {
    TextField(prompt, text: $text, axis: .vertical)
      .font(.system(.title3, design: .rounded)).lineLimit(2...4)
      .padding(20)
      .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
      .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
      .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18)) }
  }
}
