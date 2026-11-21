import SwiftUI

/// One option in the round. A single gesture tells the three actions apart so
/// rapid taps never get swallowed: a touch that ends without moving is a tap,
/// a touch held still is a pick, and a quick throw sends the bubble off screen.
struct TurboBubbleView: View {
  let bubble: TurboBubble
  let diameter: Double
  let reserve: Double
  let aboutToPop: Bool
  let splash: Double
  let save: () -> Void
  let choose: () -> Void
  let discard: () -> Void
  let dragChanged: (CGSize?) -> Void

  private struct Touch: Equatable {
    let id = UUID()
    var moved = false
    var picked = false
  }

  /// A finger can wobble this far and still count as a tap or a hold.
  private static let tapSlop: CGFloat = 12
  /// Holding starts to show after this, then the ring fills over `holdDuration`.
  private static let holdDelay = 0.18
  private static let holdDuration = 0.5

  @State private var touch: Touch?
  @State private var holdFill: CGFloat = 0
  @State private var holding = false
  @State private var tapBump = 0
  @State private var fling: CGSize?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      if bubble.isPopped && fling == nil {
        TurboLiquidBubble(title: bubble.text, slot: bubble.slot,
          style: .ghost(caption: bubble.isDiscarded ? "Let go" : "Popped"), diameter: diameter)
          .transition(.opacity)
        if !bubble.isDiscarded {
          TurboBurstView(diameter: diameter, tint: TurboPalette.color(for: bubble.slot))
        }
      } else {
        live
      }
    }
    .frame(width: diameter, height: diameter)
  }

  private var live: some View {
    TurboLiquidBubble(title: bubble.text, slot: bubble.slot, level: reserve,
      style: aboutToPop ? .aboutToPop : .live, diameter: diameter, splash: splash, taps: bubble.taps)
      .overlay {
        if holding {
          Circle().trim(from: 0, to: holdFill)
            .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(-9)
            .allowsHitTesting(false)
        }
      }
      .keyframeAnimator(initialValue: 1.0, trigger: tapBump) { content, scale in
        content.scaleEffect(scale)
      } keyframes: { _ in
        SpringKeyframe(reduceMotion ? 1 : 1.09, duration: 0.08)
        SpringKeyframe(1, duration: 0.28, spring: .bouncy)
      }
      .scaleEffect(touch != nil && fling == nil ? 0.96 : 1)
      .animation(.easeOut(duration: 0.12), value: touch != nil)
      .offset(fling ?? .zero)
      .rotationEffect(.degrees(fling == nil ? 0 : (fling!.width >= 0 ? 28 : -28)))
      .opacity(fling == nil ? 1 : 0)
      .contentShape(.circle)
      .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
        .onChanged(changed).onEnded(ended))
      .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: bubble.taps)
      .sensoryFeedback(.impact(weight: .medium), trigger: fling != nil)
      .sensoryFeedback(.success, trigger: holding && holdFill == 1)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(bubble.text)
      .accessibilityValue(aboutToPop ? "About to pop" : "Tapped \(bubble.taps) \(bubble.taps == 1 ? "time" : "times")")
      .accessibilityHint("Tap to save. Hold to pick. Flick to let go.")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { tap() }
      .accessibilityAction(named: "Pick now", choose)
      .accessibilityAction(named: "Let go", discard)
      .accessibilityIdentifier("turbo.bubble.\(bubble.slot)")
  }

  private func changed(_ value: DragGesture.Value) {
    guard fling == nil, !bubble.isPopped else { return }
    if touch == nil {
      let new = Touch()
      touch = new
      startHold(for: new.id)
    }
    let distance = hypot(value.translation.width, value.translation.height)
    if distance > Self.tapSlop, touch?.moved == false {
      touch?.moved = true
      stopHold()
    }
    if touch?.moved == true { dragChanged(value.translation) }
  }

  private func ended(_ value: DragGesture.Value) {
    stopHold()
    guard let finished = touch else { return }
    touch = nil
    guard !finished.picked, fling == nil, !bubble.isPopped else { dragChanged(nil); return }
    if !finished.moved {
      tap()
      return
    }
    let projected = value.predictedEndTranslation
    let distance = hypot(value.translation.width, value.translation.height)
    let momentum = hypot(projected.width - value.translation.width, projected.height - value.translation.height)
    if (distance >= 34 && momentum >= 48) || distance >= 140 {
      flingAway(toward: momentum >= 48 ? projected : value.translation)
    } else {
      dragChanged(nil)
    }
  }

  private func tap() {
    save()
    tapBump += 1
  }

  /// Throws the bubble off screen in the direction of the flick, then lets it go.
  private func flingAway(toward direction: CGSize) {
    let length = max(1, hypot(direction.width, direction.height))
    let target = CGSize(width: direction.width / length * 900, height: direction.height / length * 900)
    guard !reduceMotion else { finishFling(); return }
    withAnimation(.easeIn(duration: 0.32)) {
      fling = target
    } completion: {
      finishFling()
    }
  }

  private func finishFling() {
    discard()
    dragChanged(nil)
    withAnimation(.easeOut(duration: 0.25)) { fling = nil }
  }

  private func startHold(for id: UUID) {
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(Self.holdDelay))
      guard touch?.id == id, touch?.moved == false else { return }
      holdFill = 0
      holding = true
      withAnimation(.linear(duration: Self.holdDuration)) { holdFill = 1 }
      try? await Task.sleep(for: .seconds(Self.holdDuration))
      guard touch?.id == id, touch?.moved == false else { return }
      touch?.picked = true
      holding = false
      choose()
    }
  }

  private func stopHold() {
    holding = false
    holdFill = 0
  }
}
