import SwiftUI

struct TurboBubbleView: View {
  let bubble: TurboBubble
  let diameter: Double
  let reserve: Double
  let aboutToPop: Bool
  let savesLeft: Int
  let splash: Double
  let save: () -> Void
  let choose: () -> Void
  let discard: () -> Void
  let dragChanged: (CGSize?) -> Void
  @GestureState private var drag: CGSize?

  var body: some View {
    ZStack {
      if bubble.isPopped {
        TurboLiquidBubble(title: bubble.text, slot: bubble.slot,
          style: .ghost(caption: bubble.isDiscarded ? "Let go" : "Popped"), diameter: diameter)
          .transition(.opacity)
        TurboBurstView(diameter: diameter, tint: TurboPalette.color(for: bubble.slot))
      } else {
        bubbleButton
      }
    }
    .frame(width: diameter, height: diameter)
  }

  private var bubbleButton: some View {
    Button(action: save) {
      TurboLiquidBubble(title: bubble.text, slot: bubble.slot, level: reserve,
        style: aboutToPop ? .aboutToPop : .live, savesLeft: savesLeft, diameter: diameter,
        splash: splash, interactive: true)
    }
    .buttonStyle(.plain).contentShape(.circle)
    .highPriorityGesture(DragGesture(minimumDistance: 18, coordinateSpace: .global)
      .updating($drag) { value, state, _ in state = value.translation }
      .onEnded { value in
        let projected = value.predictedEndTranslation
        let distance = hypot(value.translation.width, value.translation.height)
        let momentum = hypot(projected.width - value.translation.width,
          projected.height - value.translation.height)
        if distance >= 34 && momentum >= 48 { discard() }
      })
    .onChange(of: drag) { _, translation in dragChanged(translation) }
    .onDisappear { dragChanged(nil) }
    .simultaneousGesture(LongPressGesture(minimumDuration: 0.6, maximumDistance: 14)
      .onEnded { _ in choose() })
    .sensoryFeedback(.impact(weight: .light), trigger: bubble.taps)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(bubble.text)
    .accessibilityValue(aboutToPop
      ? "About to pop, \(savesLeft) \(savesLeft == 1 ? "save" : "saves") left"
      : "\(savesLeft) \(savesLeft == 1 ? "save" : "saves") left")
    .accessibilityHint("Tap to save. Hold to pick. Flick to let go.")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Pick now", choose)
    .accessibilityAction(named: "Let go", discard)
    .accessibilityIdentifier("turbo.bubble.\(bubble.slot)")
  }
}
