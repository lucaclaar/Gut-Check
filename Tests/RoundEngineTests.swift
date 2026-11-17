import SwiftUI

@main @MainActor
struct RoundEngineTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
        guard condition() else { fatalError("FAIL: \(description)") }
        print("PASS: \(description)")
    }
    static func main() {
        let game = GutCheckModel(persistence: false)
        let first = game.choices[0].id
        game.save(first)
        expect(game.saves == 0, "Ready screen ignores gameplay gestures")
        game.start(); game.tick(1.9)
        expect(game.dangerID != nil, "Timed round threatens an option")
        if let endangered = game.dangerID {
            game.save(endangered)
            expect(game.dangerID == nil && game.saves == 1, "Saving rescues and scores exactly once")
        }
        game.pause(); let pausedElapsed = game.elapsed
        game.tick(10)
        expect(game.elapsed == pausedElapsed && game.phase == .paused, "Pause freezes timer and danger deadlines")
        game.resume(); game.tick(0.1)
        expect(game.elapsed > pausedElapsed, "Resume continues from paused time")
        game.reset(); game.start()
        let a = game.choices[0].id, b = game.choices[1].id
        game.save(a); game.save(b); game.tick(20)
        expect(game.winner?.id == b && game.phase == .done, "Score tie chooses most recently saved survivor")
        game.reset(); game.start()
        let best = game.choices[2].id
        game.save(best); game.save(best); game.save(game.choices[0].id); game.tick(20)
        expect(game.winner?.id == best, "Most-saved survivor wins at timeout")
        game.reset(); game.start(untimed: true); game.tick(200)
        expect(game.elapsed == 0 && game.dangerID == nil && game.phase == .playing, "Untimed mode disables timer and automatic elimination")
        let final = game.choices.last?.id
        for item in game.choices.dropLast() { game.pop(item.id) }
        expect(game.winner?.id == final && game.alive.count == 1, "Final remaining bubble wins; cannot discard every option")
        game.reset(); game.start(); let choice = game.choices[1].id; game.choose(choice)
        expect(game.winner?.id == choice, "Direct choice finishes immediately")
        game.reset(); game.start(); game.tick(2)
        if let danger = game.dangerID {
            game.pause(); game.tick(20); game.resume(); game.tick(1.5)
            expect(!game.alive.contains(where: { $0.id == danger }), "Expired danger removes option after resume")
        }
        game.reset()
        expect(game.saves == 0 && game.alive.count == 4 && game.winner == nil && game.phase == .ready, "Reset clears all round state")
        let duplicates = [Choice(title: "Pizza", symbol: "star", palette: 0), Choice(title: " PIZZA ", symbol: "star", palette: 1), Choice(title: "Tacos", symbol: "star", palette: 2)]
        expect(!game.updateOptions(duplicates), "Reject duplicate options after trimming and case folding")
        var blank = GutCheckModel.defaults; blank[0].title = "  "
        expect(!game.updateOptions(blank), "Reject blank option names")
        expect(!game.updateOptions(Array(GutCheckModel.defaults.prefix(2))), "Enforce at least three options")
        var valid = GutCheckModel.defaults; valid[0].title = "  Una nuova idea  "
        expect(game.updateOptions(valid) && game.choices[0].title == "Una nuova idea", "Save valid options and trim whitespace")
        print("All round engine checks passed.")
    }
}
