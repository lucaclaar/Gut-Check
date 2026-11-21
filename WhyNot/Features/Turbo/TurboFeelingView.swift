import SwiftUI

/// How the pick feels, then, if it feels not great, the option they reached for most.
struct TurboFeelingView: View {
  @Bindable var session: TurboSession
  let replay: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      Group {
        if session.reviewingPick, let runnerUp = session.runnerUp, let chosen = session.chosen {
          suggestion(runnerUp, instead: chosen)
        } else {
          rating
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.vertical, 16)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden).background(GutBackground(asset: "32-143-Glow"))
    .navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
    .navigationBarBackButtonHidden(session.reviewingPick)
    .toolbar {
      if session.reviewingPick {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", systemImage: "chevron.left", action: session.backToFeeling).labelStyle(.iconOnly)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      Group {
        if session.reviewingPick, let runnerUp = session.runnerUp, let chosen = session.chosen {
          VStack(spacing: 10) {
            GutButton(title: "Go with \(runnerUp.text)", action: session.chooseRunnerUp)
              .accessibilityIdentifier("turbo.runnerUp.switch")
            GutButton(title: "Keep \(chosen.text) anyway", prominent: false, action: session.keepOriginalPick)
            Button("Try again", action: replay)
              .font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(GutTheme.muted)
              .frame(minHeight: 44)
          }
        } else {
          GutButton(title: "Save my decision", action: session.confirmFeeling)
            .accessibilityIdentifier("turbo.save")
        }
      }
      .frame(maxWidth: 500).padding(.horizontal, 24).padding(.bottom, 20)
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.reviewingPick)
    .alert("Couldn’t save your decision", item: $session.saveError) { _ in
      Button("Try again", action: session.saveDecision)
      Button("Cancel", role: .cancel) {}
    } message: { error in Text(error) }
  }

  private var rating: some View {
    let chosen = session.chosen
    return VStack(alignment: .leading, spacing: 0) {
      Text(session.needsAlternativeFeeling
        ? "How about \(session.finalChoice?.text ?? "")?"
        : "Your gut picked \(chosen?.text ?? "").")
        .font(GutTheme.display(27)).tracking(-0.54).fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      recap(chosen).padding(.top, 18)
      GutEyebrow(title: "HOW DO YOU FEEL ABOUT IT?").padding(.top, 26)
      MascotView(name: session.feelingMascot, width: 184, height: 158)
        .frame(maxWidth: .infinity).padding(.top, 16)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: session.feelingMascot)
      Text(session.feelingTitle).font(GutTheme.display(19))
        .frame(maxWidth: .infinity).padding(.top, 8)
      Divider().padding(.top, 14).accessibilityHidden(true)
      Slider(value: $session.feeling, in: 0...1).tint(.blue)
        .accessibilityLabel("How do you feel about it?").accessibilityValue(session.feelingTitle)
        .frame(height: 52).padding(.top, 8).padding(.horizontal, 16)
      HStack { Text("Bad"); Spacer(); Text("Relieved") }
        .font(.footnote).foregroundStyle(GutTheme.muted).padding(.horizontal, 16)
        .accessibilityHidden(true)
    }
  }

  private func recap(_ chosen: TurboBubble?) -> some View {
    HStack(spacing: 6) {
      Text("Your gut said").foregroundStyle(GutTheme.muted)
      Text(chosen?.text ?? "").fontWeight(.semibold).lineLimit(1)
      Text("· \(session.elapsed.formatted(.number.precision(.fractionLength(1)))) s")
        .foregroundStyle(GutTheme.muted)
      Spacer(minLength: 8)
      HStack(spacing: 4) {
        ForEach(session.bubbles) { bubble in
          let color = TurboPalette.color(for: bubble.slot)
          Circle().fill(bubble.id == chosen?.id ? color : .clear)
            .overlay { Circle().strokeBorder(color, lineWidth: 1.5) }
            .frame(width: 8, height: 8)
        }
      }
      .accessibilityHidden(true)
    }
    .font(.system(.subheadline, design: .rounded))
    .padding(.horizontal, 14).padding(.vertical, 12)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)) }
    .accessibilityElement(children: .combine)
  }

  private func suggestion(_ runnerUp: TurboBubble, instead chosen: TurboBubble) -> some View {
    VStack(spacing: 0) {
      MascotView(name: "MascotMixedEmotions1", width: 200, height: 156).padding(.top, 8)
      Text("NOT GREAT ABOUT \(chosen.text.uppercased())?")
        .font(.system(.caption, design: .rounded).weight(.medium)).tracking(1.44)
        .foregroundStyle(GutTheme.muted).multilineTextAlignment(.center).padding(.top, 18)
      Text("Maybe it’s \(runnerUp.text).")
        .font(GutTheme.display(30)).multilineTextAlignment(.center).padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
      Text(runnerUp.taps > 0
        ? "You tapped \(runnerUp.text) \(runnerUp.taps) \(runnerUp.taps == 1 ? "time" : "times") during the round, more than any other option. Part of you wanted to keep it."
        : "You didn’t tap anything, but \(runnerUp.text) held on the longest after \(chosen.text).")
        .font(.system(.body, design: .rounded)).foregroundStyle(GutTheme.muted)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .padding(.top, 10)
      TurboLiquidBubble(title: nil, slot: runnerUp.slot, level: 0.5, diameter: 112).padding(.top, 22)
    }
    .frame(maxWidth: .infinity)
  }
}
