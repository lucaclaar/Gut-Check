import SwiftUI

struct MascotView: View {
  let name: String
  let width: Double
  let height: Double

  var body: some View {
    Image(decorative: name).resizable().scaledToFit()
      .frame(width: width, height: height)
      .accessibilityHidden(true)
  }
}
