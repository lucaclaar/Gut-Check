import SwiftUI

struct TurboBubbleView: View {
  let bubble: TurboBubble
  let diameter: Double
  let reserve: Double
  let boost: Double
  let rescue: () -> Void
  let choose: () -> Void
  let discard: () -> Void
  let dragChanged: (CGSize?) -> Void
  @GestureState private var drag: CGSize?

  var body: some View {
    ZStack {
      if bubble.isPopped {
        TurboBurstView(diameter: diameter, tint: TurboPalette.color(for: bubble.slot))
      } else {
        bubbleButton
      }
    }
    .frame(width: diameter, height: diameter)
  }

  private var bubbleButton: some View {
    Button(action: rescue) {
      TurboBubbleSurface(title: bubble.text, slot: bubble.slot, diameter: diameter)
        .overlay { TurboOrbitView(reserve: reserve) }
        .brightness(boost * 0.13)
    }
    .buttonStyle(.plain).contentShape(.circle)
    .highPriorityGesture(DragGesture(minimumDistance: 18, coordinateSpace: .global)
      .updating($drag) { value, state, _ in state = value.translation }
      .onEnded { value in
        let projected = value.predictedEndTranslation
        if hypot(value.translation.width, value.translation.height) >= 52
          || hypot(projected.width, projected.height) >= 85 { discard() }
      })
    .onChange(of: drag) { _, translation in dragChanged(translation) }
    .onDisappear { dragChanged(nil) }
    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5, maximumDistance: 14)
      .onEnded { _ in choose() })
    .sensoryFeedback(.selection, trigger: bubble.rescues)
    .accessibilityLabel(bubble.text)
    .accessibilityValue(reserve < 0.32 ? "About to burst" : "Saved \(bubble.rescues) \(bubble.rescues == 1 ? "time" : "times")")
    .accessibilityHint("Tap to refill. Hold to choose. Flick to discard.")
    .accessibilityAction(named: "Choose now", choose)
    .accessibilityAction(named: "Discard", discard)
    .accessibilityIdentifier("turbo.bubble.\(bubble.slot)")
  }
}
