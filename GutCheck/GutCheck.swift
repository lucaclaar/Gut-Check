import SwiftUI
import Observation

// One self-contained SwiftUI screen. iOS 27 / macOS 26, no dependencies.
// MARK: - Round engine

struct Choice: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var symbol: String
    var palette: Int
    var saves = 0
    var lastSave = 0
    var alive = true
    var protectedUntil = 0.0
}

enum Pace: String, CaseIterable, Codable {
    case gentle = "Calma", turbo = "Turbo", wild = "Sprint"
    var interval: Double {
        switch self { case .gentle: 3.5; case .turbo: 2.2; case .wild: 1.3 }
    }
    var rescueTime: Double { max(0.85, min(1.4, interval * 0.6)) }
    var description: String {
        switch self {
        case .gentle: "Un po’ più di spazio per sentire."
        case .turbo: "Venti secondi. Solo il tuo istinto."
        case .wild: "Meno tempo, più adrenalina."
        }
    }
}

enum RoundPhase { case ready, playing, paused, done, reflection }

@MainActor @Observable
final class GutCheckModel {
    var choices: [Choice]
    var pace: Pace = .turbo
    var phase: RoundPhase = .ready
    var elapsed = 0.0
    var dangerID: UUID?
    var dangerDeadline = 0.0
    var nextDanger = 1.8
    var winner: Choice?
    var feedback = "Le cose che salvi dicono qualcosa di te."
    var feedbackSymbol = "sparkle"
    var feedbackCount = 0
    var timerEnabled = true
    var reflection: String?
    private var saveSequence = 0
    private let persistence: Bool
    static let duration = 20.0
    static let storageKey = "gutcheck.choices.v1"
    static var defaults: [Choice] {
        [Choice(title: "Sushi", symbol: "fish.fill", palette: 0),
         Choice(title: "Pizza", symbol: "flame.fill", palette: 1),
         Choice(title: "Tacos", symbol: "sun.max.fill", palette: 2),
         Choice(title: "Ramen", symbol: "water.waves", palette: 3)]
    }

    init(persistence: Bool = true) {
        self.persistence = persistence
        if persistence,
           let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Choice].self, from: data),
           (3...6).contains(saved.count), saved.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            choices = saved
        } else { choices = Self.defaults }
    }

    var alive: [Choice] { choices.filter(\.alive) }
    var remaining: Int { max(0, Int(ceil(Self.duration - elapsed))) }
    var saves: Int { choices.reduce(0) { $0 + $1.saves } }
    var isActive: Bool { phase == .playing }

    func reset() {
        choices = choices.map { Choice(title: $0.title, symbol: $0.symbol, palette: $0.palette) }
        elapsed = 0; dangerID = nil; nextDanger = 1.8; dangerDeadline = 0
        saveSequence = 0; winner = nil; reflection = nil; phase = .ready
        feedback = "Le cose che salvi dicono qualcosa di te."; feedbackSymbol = "sparkle"
    }

    @discardableResult func updateOptions(_ draft: [Choice]) -> Bool {
        var normalized = draft
        for i in normalized.indices {
            normalized[i].title = String(normalized[i].title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        }
        let keys = normalized.map { $0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard (3...6).contains(normalized.count), keys.allSatisfy({ !$0.isEmpty }), Set(keys).count == keys.count else { return false }
        choices = normalized; reset()
        if persistence, let data = try? JSONEncoder().encode(choices) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        return true
    }

    func start(untimed: Bool = false) {
        guard phase == .ready else { return }
        timerEnabled = !untimed; phase = .playing
        feedback = untimed ? "Prenditi il tuo tempo. Ascoltati." : "Quale non vuoi perdere?"; feedbackSymbol = "hand.tap"
    }
    func pause() { if phase == .playing { phase = .paused } }
    func resume() { if phase == .paused { phase = .playing } }

    func tick(_ delta: Double) {
        guard phase == .playing, timerEnabled else { return }
        elapsed = min(Self.duration, elapsed + max(0, delta))
        if elapsed >= Self.duration { finishByScore(); return }
        if let id = dangerID, elapsed >= dangerDeadline { pop(id); if phase != .playing { return } }
        if dangerID == nil, elapsed >= nextDanger {
            let candidates = choices.filter { $0.alive && $0.protectedUntil <= elapsed }
            if let choice = candidates.randomElement(), alive.count > 1 {
                dangerID = choice.id; dangerDeadline = elapsed + pace.rescueTime
                feedback = "\(choice.title) sta per scoppiare…"; feedbackSymbol = "exclamationmark"
            }
            nextDanger = elapsed + pace.interval
        }
    }

    func save(_ id: UUID) {
        guard phase == .playing, let i = choices.firstIndex(where: { $0.id == id && $0.alive }) else { return }
        let rescued = dangerID == id
        if rescued { dangerID = nil }
        saveSequence += 1; choices[i].saves += 1; choices[i].lastSave = saveSequence
        choices[i].protectedUntil = elapsed + pace.interval
        feedback = rescued ? "\(choices[i].title), appena in tempo." : "Hai salvato \(choices[i].title)."
        feedbackSymbol = "heart.fill"; feedbackCount += 1
    }

    func pop(_ id: UUID) {
        guard phase == .playing, alive.count > 1,
              let i = choices.firstIndex(where: { $0.id == id && $0.alive }) else { return }
        choices[i].alive = false
        if dangerID == id { dangerID = nil }
        feedback = "Hai lasciato andare \(choices[i].title)."; feedbackSymbol = "wind"
        feedbackCount += 1
        if alive.count == 1, let last = alive.first { finish(last) }
    }

    func choose(_ id: UUID) {
        guard phase == .playing, let choice = alive.first(where: { $0.id == id }) else { return }
        finish(choice)
    }

    func finishByScore() {
        guard phase == .playing, let best = alive.max(by: {
            $0.saves == $1.saves ? $0.lastSave < $1.lastSave : $0.saves < $1.saves
        }) else { return }
        finish(best)
    }
    private func finish(_ choice: Choice) {
        winner = choice; dangerID = nil; phase = .done; feedbackCount += 1
    }
}

#if !MODEL_TESTS
// MARK: - Visual language

enum GC {
    static let ink = Color(red: 0.035, green: 0.038, blue: 0.064)
    static let cream = Color(red: 1, green: 0.89, blue: 0.65)
    static let muted = Color(red: 0.62, green: 0.63, blue: 0.70)
    static let amber = Color(red: 1, green: 0.75, blue: 0.36)
    static let colors: [Color] = [
        Color(red: 1, green: 0.73, blue: 0.36),
        Color(red: 0.73, green: 0.65, blue: 1),
        Color(red: 1, green: 0.51, blue: 0.47),
        Color(red: 0.52, green: 0.85, blue: 0.77)
    ]
    static func color(_ index: Int) -> Color { colors[abs(index % colors.count)] }
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.72)
}

@main
struct GutCheckApp: App {
    var body: some Scene {
        WindowGroup {
            GutCheckView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 390, idealWidth: 440, maxWidth: 650, minHeight: 700, idealHeight: 880)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 440, height: 880)
        #endif
    }
}

struct GutCheckView: View {
    @State private var model = GutCheckModel()
    @State private var editing = false
    @State private var showingHelp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 690
            ZStack {
                AtmosphereView()
                ScrollView {
                    VStack(spacing: 0) {
                        masthead
                            .padding(.bottom, compact ? 20 : 30)
                        if model.phase == .done || model.phase == .reflection {
                            result
                        } else {
                            introduction(compact: compact)
                            arena(compact: compact)
                            footer
                        }
                    }
                    .frame(maxWidth: 510)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 26)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .accessibilityHidden(model.phase == .paused)
                if model.phase == .paused { pauseOverlay }
            }
        }
        .foregroundStyle(.white)
        .tint(GC.amber)
        .sheet(isPresented: $editing) { OptionsEditor(model: model) }
        .sheet(isPresented: $showingHelp) { helpSheet }
        .task {
            let clock = ContinuousClock()
            var previous = clock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                let now = clock.now
                let components = previous.duration(to: now).components
                let delta = Double(components.seconds) + Double(components.attoseconds) / 1e18
                previous = now
                model.tick(delta)
            }
        }
        .onChange(of: scenePhase) { if scenePhase != .active { model.pause() } }
        .onChange(of: voiceOver) { if voiceOver { model.timerEnabled = false; model.dangerID = nil } }
        .sensoryFeedback(.selection, trigger: model.feedbackCount)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: model.phase)
    }

    private var masthead: some View {
        HStack(spacing: 10) {
            BrandMark(size: 33)
            Text("gut check")
                .font(.title3.weight(.bold))
                .tracking(-0.6)
            Spacer()
            Button("Come funziona", systemImage: "questionmark") { showingHelp = true }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
                .buttonStyle(.plain)
        }
    }

    private func introduction(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 17) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill").font(.caption)
                Text("MODALITÀ TURBO").font(.caption.weight(.bold)).tracking(2.4)
                Spacer()
                if model.phase == .playing {
                    Button("Pausa", systemImage: "pause.fill", action: model.pause)
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle).buttonStyle(.plain)
                } else {
                    Text("20 SEC").font(.caption.monospaced()).tracking(1.5).foregroundStyle(GC.muted)
                }
            }
            .foregroundStyle(GC.cream)
            Text(model.phase == .playing ? "Non pensarci.\nSalvala." : "Meno pensieri.\nPiù istinto.")
                .font(.largeTitle.weight(.bold).scaled(by: compact ? 1.02 : 1.15))
                .tracking(-1.8)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.phase == .playing ? "Tocca ciò che non vuoi lasciar andare." : "La tua scelta è nelle cose che non vuoi perdere.")
                .font(.subheadline)
                .foregroundStyle(GC.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func arena(compact: Bool) -> some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(model.isActive ? Color.green.opacity(0.8) : GC.amber).frame(width: 5, height: 5)
                    Text(model.isActive ? "ASCOLTA IL TUO ISTINTO" : "COSA TI VA STASERA?")
                        .font(.caption.weight(.medium)).tracking(1.5)
                }
                .foregroundStyle(GC.muted)
                Spacer(minLength: 8)
                if model.isActive {
                    TimerPill(remaining: model.remaining, enabled: model.timerEnabled)
                } else {
                    Text("\(model.choices.count) possibilità").font(.caption).foregroundStyle(GC.muted)
                }
            }
            .padding(.top, compact ? 22 : 30)
            .padding(.bottom, 4)
            BubbleArena(model: model, compact: compact)
                .frame(height: compact ? 270 : (model.choices.count > 4 ? 360 : 315))
            HStack(spacing: 7) {
                Image(systemName: model.feedbackSymbol)
                    .foregroundStyle(model.dangerID == nil ? GC.cream : .orange)
                Text(model.feedback).foregroundStyle(GC.muted)
            }
            .font(.caption)
            .frame(minHeight: 32)
            .contentTransition(.opacity)
            .accessibilityElement(children: .combine)
        }
    }

    private var footer: some View {
        VStack(spacing: 18) {
            GestureGuide()
            if model.phase == .ready {
                HStack(spacing: 12) {
                    Button { editing = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .frame(width: 56, height: 56)
                    }
                    .accessibilityLabel("Modifica opzioni e velocità")
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    Button { model.start(untimed: voiceOver || !model.timerEnabled) } label: {
                        HStack {
                            Spacer()
                            Text("Segui l’istinto").font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right").font(.body.weight(.semibold))
                        }
                        .padding(.horizontal, 22).frame(height: 56)
                        .foregroundStyle(GC.ink)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(GC.cream).interactive(), in: .capsule)
                }
            } else {
                HStack(spacing: 9) {
                    Image(systemName: "hand.point.up.left")
                    Text("Hai già scelto? Tieni premuta una bolla.")
                }
                .font(.subheadline).foregroundStyle(GC.cream)
                .frame(maxWidth: .infinity).frame(minHeight: 56)
                .glassEffect(.regular, in: .capsule)
            }
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").font(.caption)
                Text("Nessuna risposta giusta. Solo la tua.").font(.caption)
            }
            .foregroundStyle(GC.muted.opacity(0.8))
        }
        .padding(.top, 13)
    }

    private var pauseOverlay: some View {
        ZStack {
            GC.ink.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "pause.circle").font(.largeTitle).foregroundStyle(GC.cream)
                Text("Un respiro.").font(.largeTitle.bold()).tracking(-1)
                Text("Le tue possibilità ti aspettano.").foregroundStyle(GC.muted)
                Button("Riprendi", systemImage: "play.fill", action: model.resume)
                    .buttonStyle(.glassProminent).tint(GC.cream).controlSize(.large)
                Button("Ricomincia", action: model.reset).buttonStyle(.glass).controlSize(.large)
            }
            .padding(32)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var result: some View {
        VStack(spacing: 22) {
            Label("IL TUO ISTINTO HA PARLATO", systemImage: "sparkles")
                .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(GC.cream)
                .padding(.top, 24)
            Text(model.phase == .reflection ? "Come ti fa sentire?" : "La volevi già.")
                .font(.largeTitle.bold()).tracking(-1.7)
                .multilineTextAlignment(.center)
            if let winner = model.winner {
                OrbArtwork(choice: winner, diameter: 205, danger: false, holding: false)
                    .padding(.vertical, 14)
                if model.phase == .done {
                    Text(winner.saves > 0 ? "L’hai salvata \(winner.saves) volte.\nA volte, la risposta è un riflesso." : "È la possibilità che hai tenuto con te.\nOra ascolta come ti fa sentire.")
                        .font(.body).foregroundStyle(GC.muted)
                        .multilineTextAlignment(.center).lineSpacing(5)
                    HStack(spacing: 18) {
                        Label("\(Int(model.elapsed.rounded())) secondi", systemImage: "timer")
                        Label("\(model.saves) salvataggi", systemImage: "heart")
                    }
                    .font(.caption).foregroundStyle(GC.cream)
                    .padding(.vertical, 8)
                    primaryButton("È la mia scelta", symbol: "arrow.right") { model.phase = .reflection }
                    Button("Voglio riprovare", action: model.reset)
                        .font(.subheadline).foregroundStyle(GC.muted).frame(minHeight: 44).buttonStyle(.plain)
                } else {
                    Text("\(winner.title). Sollievo o un piccolo dubbio?\nAnche questa reazione è una risposta.")
                        .font(.body).foregroundStyle(GC.muted).multilineTextAlignment(.center).lineSpacing(5)
                    HStack(spacing: 12) {
                        reflectionButton("Mi somiglia", symbol: "heart.fill")
                        reflectionButton("Ho un dubbio", symbol: "cloud")
                    }
                    if let reflection = model.reflection {
                        Text(reflection == "Mi somiglia" ? "Allora fidati. Buona scelta ✨" : "Puoi cambiare idea. È il bello di scegliere.")
                            .font(.subheadline).foregroundStyle(GC.cream).multilineTextAlignment(.center)
                    }
                    primaryButton("Un nuovo gut check", symbol: "arrow.counterclockwise", action: model.reset)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func reflectionButton(_ title: String, symbol: String) -> some View {
        Button { model.reflection = title } label: {
            Label(title, systemImage: symbol).font(.subheadline)
                .frame(maxWidth: .infinity).frame(minHeight: 54)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(model.reflection == title ? GC.amber.opacity(0.35) : .clear).interactive(), in: .capsule)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity).frame(minHeight: 56).foregroundStyle(GC.ink)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(GC.cream).interactive(), in: .capsule)
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Il corpo sceglie.\nLa mente arriva dopo.")
                        .font(.largeTitle.bold()).tracking(-1.4)
                    Text("In venti secondi, alcune possibilità iniziano a scomparire. Nota quali ti viene spontaneo salvare.")
                        .foregroundStyle(.secondary)
                    HelpRow(symbol: "hand.tap", title: "Tocca per salvare", text: "Una bolla diventa corallo? Toccala prima che scoppi. Puoi salvare anche le altre, quando vuoi.")
                    HelpRow(symbol: "arrow.up.right", title: "Trascina per lasciare andare", text: "Lancia una bolla lontano se senti che non fa per te.")
                    HelpRow(symbol: "hand.point.up.left", title: "Tieni premuto per scegliere", text: "Ti bastano 0,7 secondi per dire: è questa.")
                    Text("Allo scadere vince la bolla rimasta con più salvataggi. A parità, conta l’ultimo tocco. Puoi mettere in pausa in qualsiasi momento o disattivare il timer nelle opzioni.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(26)
            }
            .navigationTitle("Come funziona")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Chiudi") { showingHelp = false } } }
        }
        .presentationDetents([.large])
        .frame(minWidth: 340, minHeight: 550)
        .preferredColorScheme(.dark)
    }
}

struct AtmosphereView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                GC.ink
                Ellipse().fill(Color(red: 0.48, green: 0.27, blue: 0.10).opacity(0.32))
                    .frame(width: geo.size.width * 1.15, height: 500)
                    .blur(radius: 95).position(x: 0, y: geo.size.height * 0.18)
                Ellipse().fill(Color(red: 0.26, green: 0.20, blue: 0.57).opacity(0.36))
                    .frame(width: geo.size.width, height: 450)
                    .blur(radius: 85).position(x: geo.size.width * 1.05, y: geo.size.height * 0.58)
                Ellipse().fill(Color(red: 0.10, green: 0.28, blue: 0.29).opacity(0.2))
                    .frame(width: 250, height: 180)
                    .blur(radius: 70).position(x: 50, y: geo.size.height * 0.92)
                Canvas { context, size in
                    for index in 0..<50 {
                        let x = Double((index * 137 + 41) % 997) / 997 * size.width
                        let y = Double((index * 233 + 19) % 991) / 991 * size.height
                        let side = index % 6 == 0 ? 1.8 : 0.8
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)), with: .color(.white.opacity(index % 3 == 0 ? 0.24 : 0.10)))
                    }
                }
            }
        }
        .ignoresSafeArea().accessibilityHidden(true)
    }
}

struct BrandMark: View {
    let size: Double
    var body: some View {
        ZStack {
            Circle().fill(.radialGradient(colors: [GC.cream, GC.amber, Color(red: 0.45, green: 0.24, blue: 0.09)], center: .topLeading, startRadius: 0, endRadius: size))
            Image(systemName: "sparkle").font(.system(size: size * 0.48, weight: .medium)).foregroundStyle(GC.ink)
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.6) }
        .accessibilityHidden(true)
    }
}

struct TimerPill: View {
    let remaining: Int
    let enabled: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: enabled ? "timer" : "infinity").font(.caption)
            if enabled { Text("0:\(remaining < 10 ? "0" : "")\(remaining)").monospacedDigit().contentTransition(.numericText(countsDown: true)) }
            else { Text("Senza fretta") }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(remaining <= 5 && enabled ? .orange : GC.cream)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel(enabled ? "\(remaining) secondi rimanenti" : "Timer disattivato")
    }
}

struct BubbleArena: View {
    let model: GutCheckModel
    let compact: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func point(_ index: Int, count: Int) -> UnitPoint {
        let points: [UnitPoint]
        switch count {
        case 3: points = [.init(x: 0.26, y: 0.26), .init(x: 0.75, y: 0.35), .init(x: 0.44, y: 0.77)]
        case 5: points = [.init(x: 0.25, y: 0.19), .init(x: 0.76, y: 0.21), .init(x: 0.48, y: 0.52), .init(x: 0.2, y: 0.82), .init(x: 0.79, y: 0.82)]
        case 6: points = [.init(x: 0.24, y: 0.18), .init(x: 0.77, y: 0.19), .init(x: 0.23, y: 0.50), .init(x: 0.76, y: 0.51), .init(x: 0.26, y: 0.83), .init(x: 0.77, y: 0.84)]
        default: points = [.init(x: 0.26, y: 0.26), .init(x: 0.76, y: 0.30), .init(x: 0.23, y: 0.76), .init(x: 0.73, y: 0.78)]
        }
        return points[min(index, points.count - 1)]
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle().stroke(.white.opacity(0.035), lineWidth: 1).frame(width: geo.size.width * 0.96)
                Circle().stroke(.white.opacity(0.025), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
                    .frame(width: geo.size.width * 0.67)
                Image(systemName: "plus").font(.caption).foregroundStyle(.white.opacity(0.1)).accessibilityHidden(true)
                GlassEffectContainer(spacing: 8) {
                    ZStack {
                    ForEach(model.choices.enumerated(), id: \.element.id) { index, choice in
                        if choice.alive {
                            let p = point(index, count: model.choices.count)
                            let size = min(geo.size.width * (model.choices.count > 4 ? 0.29 : 0.36), compact ? 113 : 135)
                            BubbleView(choice: choice, model: model, diameter: size)
                                .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                                .transition(.asymmetric(insertion: .opacity, removal: reduceMotion ? .opacity : .scale(scale: 0.15).combined(with: .opacity)))
                        }
                    }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .animation(reduceMotion ? .none : GC.spring, value: model.alive.count)
        }
    }
}

struct BubbleView: View {
    let choice: Choice
    let model: GutCheckModel
    let diameter: Double
    @State private var drag = CGSize.zero
    @State private var pressing = false
    @State private var holdCompleted = false
    @State private var floating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var danger: Bool { model.dangerID == choice.id }

    var body: some View {
        OrbArtwork(choice: choice, diameter: diameter, danger: danger, holding: pressing)
            .scaleEffect(pressing ? 0.94 : 1)
            .offset(x: drag.width, y: drag.height + (floating && !reduceMotion ? -5 : 0))
            .contentShape(.circle)
            .onTapGesture { if !holdCompleted { model.save(choice.id) } }
            .onLongPressGesture(minimumDuration: 0.7, maximumDistance: 16) {
                holdCompleted = true; model.choose(choice.id)
            } onPressingChanged: { value in
                if value { holdCompleted = false }
                withAnimation(reduceMotion ? .none : .easeInOut(duration: value ? 0.7 : 0.15)) {
                    pressing = value && model.isActive
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in if model.isActive { drag = value.translation; pressing = false } }
                    .onEnded { value in
                        let actual = hypot(value.translation.width, value.translation.height)
                        let predicted = hypot(value.predictedEndTranslation.width, value.predictedEndTranslation.height)
                        if actual > 90 || (actual > 18 && predicted > 180) { model.pop(choice.id) }
                        withAnimation(reduceMotion ? .none : GC.spring) { drag = .zero }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(choice.title)
            .accessibilityValue("\(choice.saves) salvataggi\(danger ? ", sta per scoppiare" : "")")
            .accessibilityHint(model.isActive ? "Attiva per salvare. Altre azioni per scegliere o scartare." : "Inizia il round per scegliere.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.save(choice.id) }
            .accessibilityAction(named: "Scegli ora") { model.choose(choice.id) }
            .accessibilityAction(named: "Scarta") { model.pop(choice.id) }
            .task {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.3 + Double(choice.palette) * 0.3).repeatForever(autoreverses: true)) { floating = true }
            }
    }
}

struct OrbArtwork: View {
    let choice: Choice
    let diameter: Double
    let danger: Bool
    let holding: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var color: Color { danger ? .orange : GC.color(choice.palette) }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.13)).blur(radius: 20).padding(-7)
            Circle()
                .fill(.radialGradient(colors: [color.opacity(0.10), color.opacity(0.035), color.opacity(0.35)], center: .init(x: 0.4, y: 0.32), startRadius: 0, endRadius: diameter * 0.7))
                .overlay {
                    Circle().strokeBorder(.linearGradient(colors: [.white.opacity(0.85), color.opacity(0.5), .white.opacity(0.05), color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
                .overlay {
                    Ellipse().fill(.white.opacity(0.22)).frame(width: diameter * 0.32, height: diameter * 0.11)
                        .blur(radius: 5).rotationEffect(.degrees(-32)).offset(x: -diameter * 0.19, y: -diameter * 0.31)
                }
                .shadow(color: color.opacity(0.16), radius: 22, y: 10)
            VStack(spacing: diameter > 150 ? 12 : 7) {
                Image(systemName: choice.symbol)
                    .font(diameter > 150 ? .title : .title3)
                    .foregroundStyle(color.opacity(0.95))
                    .symbolRenderingMode(.hierarchical)
                Text(choice.title).font(diameter > 150 ? .title2.bold() : .headline)
                    .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            if choice.saves > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill").font(.system(size: 8))
                    Text("\(choice.saves)").font(.caption.weight(.bold))
                }
                .foregroundStyle(GC.ink).padding(.horizontal, 8).padding(.vertical, 5)
                .background(color.gradient, in: .capsule)
                .offset(x: diameter * 0.31, y: -diameter * 0.36)
            }
            if danger {
                Circle().stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 5])).padding(-7)
                Image(systemName: "exclamationmark").font(.caption.bold())
                    .padding(7).background(.orange, in: .circle).foregroundStyle(GC.ink)
                    .offset(y: diameter * 0.5)
            }
            Circle().trim(from: 0, to: holding ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(-5)
        }
        .frame(width: diameter, height: diameter)
        .glassEffect(.clear.tint(color.opacity(reduceTransparency ? 0.65 : 0.15)).interactive(), in: .circle)
    }
}

struct GestureGuide: View {
    var body: some View {
        HStack(spacing: 0) {
            gesture("hand.tap", title: "Tocca", subtitle: "salva")
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 24)
            gesture("arrow.up.right", title: "Trascina", subtitle: "scarta")
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 24)
            gesture("hand.point.up.left", title: "Tieni", subtitle: "scegli")
        }
        .padding(.vertical, 15)
        .background(.white.opacity(0.035), in: .rect(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(0.06), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
    private func gesture(_ symbol: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.body).foregroundStyle(GC.cream).frame(height: 20)
            Text(title).font(.caption.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(GC.muted)
        }.frame(maxWidth: .infinity)
    }
}

struct HelpRow: View {
    let symbol: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol).font(.title2).foregroundStyle(GC.amber).frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OptionsEditor: View {
    let model: GutCheckModel
    @State private var draft: [Choice] = []
    @State private var pace: Pace = .turbo
    @State private var timed = true
    @State private var validationError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($draft) { $choice in
                        HStack(spacing: 12) {
                            Image(systemName: choice.symbol).foregroundStyle(GC.color(choice.palette)).frame(width: 24)
                            TextField("Una possibilità", text: $choice.title)
                                .accessibilityLabel("Nome dell’opzione")
                            Button("Rimuovi \(choice.title)", systemImage: "minus.circle") {
                                draft.removeAll { $0.id == choice.id }
                            }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                            .disabled(draft.count <= 3).frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    if draft.count < 6 {
                        Button("Aggiungi possibilità", systemImage: "plus.circle") {
                            draft.append(Choice(title: "", symbol: "sparkles", palette: draft.count))
                        }.frame(minHeight: 44)
                    }
                } header: { Text("Le tue possibilità") }
                footer: { Text("Da 3 a 6 opzioni diverse. Fino a 20 caratteri ciascuna.") }
                Section("Il tuo ritmo") {
                    Picker("Velocità", selection: $pace) { ForEach(Pace.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    Text(pace.description).font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Timer e bolle a tempo", isOn: $timed)
                    Text("Disattivalo per scegliere senza fretta. Con VoiceOver, il round parte sempre senza timer.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Ripristina Sushi, Pizza, Tacos e Ramen") { draft = GutCheckModel.defaults }
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle("Fai spazio alle possibilità")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        if model.updateOptions(draft) { model.pace = pace; model.timerEnabled = timed; dismiss() }
                        else { validationError = true }
                    }.bold()
                }
            }
            .alert("Ogni possibilità merita un nome diverso", isPresented: $validationError) {
                Button("Va bene", role: .cancel) { }
            } message: { Text("Inserisci da 3 a 6 nomi, senza campi vuoti o duplicati.") }
            .onAppear { draft = model.choices; pace = model.pace; timed = model.timerEnabled }
        }
        .presentationDetents([.large])
        .frame(minWidth: 350, minHeight: 540)
        .preferredColorScheme(.dark).tint(GC.amber)
    }
}

#Preview { GutCheckView().preferredColorScheme(.dark) }
#endif
