import StrapLogCore

/// Records what a `TrainingRunner` says, with the fake time of each line.
@MainActor
final class VoiceSpy: TrainingVoice {
    struct Line: Equatable {
        let atMs: Int64
        let text: String
    }

    let clock: FakeClock
    private(set) var lines: [Line] = []
    private(set) var begins = 0
    private(set) var ends = 0

    init(clock: FakeClock) { self.clock = clock }

    var texts: [String] { lines.map(\.text) }

    func begin() { begins += 1 }
    func say(_ text: String) { lines.append(Line(atMs: clock.nowMs(), text: text)) }
    func end() { ends += 1 }
}
