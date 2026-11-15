import Testing
@testable import StrapLogCore

@Suite("TrainingScript")
struct TrainingScriptTests {
    static let scripts = TrainingScript.all

    @Test("every rate is one the pacer accepts (its init is a precondition)", arguments: scripts)
    func rates(_ script: TrainingScript) {
        for step in script.steps {
            if let rate = step.pacerRate { #expect(BreathingPacer.rates.contains(rate), "\(step.label)") }
        }
    }

    @Test("every paced step is a whole number of breaths, so it ends on an out-breath", arguments: scripts)
    func wholeBreaths(_ script: TrainingScript) throws {
        for step in script.steps {
            guard let breaths = step.breaths else { continue }
            #expect(abs(breaths - breaths.rounded()) < 1e-9, "\(step.label): \(breaths) breaths")
        }
    }

    @Test("labels are unique, and none is a label the runner logs itself", arguments: scripts)
    func uniqueLabels(_ script: TrainingScript) {
        let labels = script.steps.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(!labels.contains(TrainingScript.endLabel))
        #expect(!labels.contains(TrainingScript.abortedLabel))
        #expect(labels.first == TrainingScript.introLabel)
    }

    @Test("every mid-step line falls inside its step, in order", arguments: scripts)
    func linesInside(_ script: TrainingScript) {
        for step in script.steps {
            let times = step.lines.map(\.afterMs)
            #expect(times == times.sorted(), "\(step.label)")
            #expect(times.allSatisfy { $0 > 0 && $0 < step.durationMs }, "\(step.label)")
        }
    }

    @Test("a warning one breath before a hold lands 1 s into the last in-breath")
    func lastBreath() throws {
        let follow8 = try #require(TrainingScript.calibration.steps.first { $0.label == "follow_8" })
        #expect(follow8.lines.map(\.afterMs) == [120_000 - 7_500 + 1_000])
        let next = TrainingScript.calibration.steps.firstIndex(of: follow8)! + 1
        #expect(TrainingScript.calibration.steps[next].label == "hold_1")
    }

    @Test("calibration: each paced step is a cold start plus a full 60 s window, and at least 8 breaths")
    func lengthRule() {
        for step in TrainingScript.calibration.steps where step.pacerRate != nil && !step.label.hasPrefix("recover") {
            #expect(step.durationMs >= 120_000, "\(step.label)")
            #expect((step.breaths ?? 0) >= 8, "\(step.label)")
        }
    }

    @Test("calibration: holds are 30 s, twice, each after a paced step; the whole is about 19 min")
    func shape() {
        let steps = TrainingScript.calibration.steps
        let holds = steps.enumerated().filter { $0.element.label.hasPrefix("hold") }
        #expect(holds.map(\.element.durationMs) == [30_000, 30_000])
        #expect(holds.allSatisfy { steps[$0.offset - 1].pacerRate != nil })
        #expect(TrainingScript.calibration.totalMs == 1_120_000)
        #expect(TrainingScript.calibration.stamp == "calibration v1")
        #expect(TrainingScript.rehearsal.totalMs <= 150_000)
    }
}

extension TrainingScript: CustomTestStringConvertible {
    public var testDescription: String { stamp }
}
