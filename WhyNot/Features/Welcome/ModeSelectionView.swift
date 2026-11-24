import SwiftUI

struct ModeSelectionView: View {
  let session: ReflectionSession
  let turbo: TurboSession
  let resume: (RecentDecision) -> Void
  let delete: (RecentDecision) throws -> Void
  let startTurbo: () -> Void

  private enum Sheet: Hashable, Identifiable {
    case help, waiting
    var id: Self { self }
  }

  @AppStorage("hasSeenHomeTip") private var hasSeenHomeTip = false
  @AppStorage("hasDoneCardPractice") private var hasDoneCardPractice = false
  @AppStorage("turboSoundEnabled") private var soundOn = true
  @State private var sheet: Sheet?
  @State private var pendingResume: RecentDecision?
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let sideBySide = size.width >= 700 && size.height < 520
      let expansion = typeSize.isAccessibilitySize ? 0 : min(1, max(0, (size.height - 680) / 110))
      let topInset = min(36, size.height * 0.055)
      ViewThatFits(in: .vertical) {
        content(sideBySide: sideBySide, expansion: expansion)
          .padding(.top, topInset)
        content(sideBySide: sideBySide)
          .padding(.top, topInset)
        ScrollView {
          content(sideBySide: sideBySide)
            .padding(.top, 12)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        waitingButton.padding(.bottom, 44 * expansion)
      }
    }
    .background(GutBackground())
    .navigationTitle("Gut Check")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("How it works", systemImage: "questionmark", action: showHelp)
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("home.help")
      }
      ToolbarItem(placement: .principal) {
        Text("Gut Check")
          .font(GutTheme.display(16))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .accessibilityAddTraits(.isHeader)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Turbo sounds", systemImage: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
          soundOn.toggle()
        }
        .labelStyle(.iconOnly)
        .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        .accessibilityValue(soundOn ? "On" : "Off")
        .accessibilityIdentifier("home.turboSound")
      }
    }
    .sheet(item: $sheet, onDismiss: resumeAfterDismissal) { presentedSheet in
      switch presentedSheet {
      case .help:
        HomeHelpView()
      case .waiting:
        WaitingForYouView(session: session, turbo: turbo, delete: delete) { activity in
          pendingResume = activity
          sheet = nil
        }
      }
    }
    .onChange(of: session.path.isEmpty) { _, isHome in
      if !isHome { sheet = nil }
    }
  }

  private var waitingButton: some View {
    Button {
      sheet = .waiting
    } label: {
      Label("Waiting for you", systemImage: "chevron.up")
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 6)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
    .padding(.vertical, 8)
    .accessibilityIdentifier("home.waiting")
  }

  private func content(sideBySide: Bool, expansion: CGFloat = 0) -> some View {
    let showMascotTip = !hasSeenHomeTip && !sideBySide && !typeSize.isAccessibilitySize
    let cardExtraHeight = 42 * expansion
    let layout = sideBySide
      ? AnyLayout(HStackLayout(spacing: 14))
      : AnyLayout(VStackLayout(spacing: 14 + 4 * expansion))

    return VStack(alignment: .leading, spacing: showMascotTip ? 4 : 20 + 10 * expansion) {
      Text("How do you want to decide?")
        .font(GutTheme.display(27))
        .tracking(-0.54)
        .multilineTextAlignment(.leading)
        .accessibilityAddTraits(.isHeader)

      if !hasSeenHomeTip && !showMascotTip {
        TipBubble(dismiss: dismissTip)
      }

      layout {
        VStack(alignment: .trailing, spacing: -(32 + cardExtraHeight / 2)) {
          if showMascotTip {
            TipBubble(dismiss: dismissTip)
              .padding(.trailing, -12)
              .zIndex(1)
          }

          Button {
            dismissTip()
            session.start()
          } label: {
            ModeCard(title: "Reflect",
              subtitle: "When you don’t have all the options and need time to think.",
              mascot: "MascotStillDoubtful1", isReflect: true, extraHeight: cardExtraHeight)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("mode.reflect")
        }

        Button {
          dismissTip()
          startTurbo()
        } label: {
          ModeCard(title: "Turbo", subtitle: "Few options to make a quick decision.",
            mascot: "MascotWorstCase3", isReflect: false, extraHeight: cardExtraHeight)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mode.turbo")
      }
    }
    .padding(.bottom, 12)
    .frame(maxWidth: sideBySide ? 700 : 500)
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func resumeAfterDismissal() {
    guard let activity = pendingResume else { return }
    pendingResume = nil
    if session.path.isEmpty { resume(activity) }
  }

  private func showHelp() {
    hasSeenHomeTip = true
    hasDoneCardPractice = false
    sheet = .help
  }

  private func dismissTip() {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { hasSeenHomeTip = true }
  }
}
