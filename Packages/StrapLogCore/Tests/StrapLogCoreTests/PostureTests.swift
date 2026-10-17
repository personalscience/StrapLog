import Testing
@testable import StrapLogCore

/// A second whose mean gravity vector is (x, y, z) mg.
func still(_ secondMs: Int64, _ x: Double, _ y: Double, _ z: Double, n: Int = 25) -> MotionSecond {
    MotionSecond(recordingId: 1, secondMs: secondMs, rmsMg: 3, gxMg: x, gyMg: y, gzMg: z, n: n)
}

/// `count` consecutive seconds from `fromMs` in one posture: upright as at the gym, lying on the side.
func seconds(_ posture: Posture, fromMs: Int64, count: Int) -> [MotionSecond] {
    (0..<count).map { i in
        let t = fromMs + Int64(i) * 1000
        return posture == .upright ? still(t, -880, 80, 412) : still(t, -363, -909, 207)
    }
}

@Suite("Posture")
struct PostureTests {
    @Test("10-min means from the 2026-10-15 night and gym session classify as worn")
    func deviceNight() {
        #expect(Posture.of(still(0, -880, 80, 412)) == .upright, "standing at the gym")
        #expect(Posture.of(still(0, -808, 21, 576)) == .upright, "sitting, evening")
        #expect(Posture.of(still(0, -363, -909, 207)) == .lying, "side-lying, head on pillow")
        #expect(Posture.of(still(0, 280, 5, 938)) == .lying, "on the back")
        #expect(Posture.of(still(0, -44, 968, 274)) == .lying, "other side")
        #expect(Posture.of(still(0, -443, 37, 887)) == .lying, "reclined on the couch")
    }

    @Test("a strap worn upside down reads the same; an unusable second reads nil")
    func edges() {
        #expect(Posture.of(still(0, 880, -80, 412)) == .upright)
        #expect(Posture.of(still(0, -100, 50, 100)) == nil, "gravity vector too short")
        #expect(Posture.of(still(0, -880, 80, 412, n: 0)) == nil)
    }
}

@Suite("PostureTracker")
struct PostureTrackerTests {
    @Test("a posture counts once it holds for holdMs, dated from its first second")
    func confirms() {
        var t = PostureTracker(holdMs: 60_000)
        #expect(t.add(seconds(.lying, fromMs: 0, count: 59)).isEmpty)
        #expect(t.posture == nil)
        #expect(t.add(seconds(.lying, fromMs: 59_000, count: 1)) == [.init(atMs: 0, posture: .lying)])
        #expect(t.add(seconds(.lying, fromMs: 60_000, count: 30)).isEmpty, "no repeat while it holds")
        #expect(t.add(seconds(.upright, fromMs: 90_000, count: 60)) == [.init(atMs: 90_000, posture: .upright)])
    }

    @Test("a contrary second restarts the hold, so turning over or bending does not flap")
    func noFlap() {
        var t = PostureTracker(holdMs: 60_000)
        _ = t.add(seconds(.lying, fromMs: 0, count: 60))
        var changes = t.add(seconds(.upright, fromMs: 60_000, count: 40))
        changes += t.add(seconds(.lying, fromMs: 100_000, count: 1))
        changes += t.add(seconds(.upright, fromMs: 101_000, count: 40))
        #expect(changes.isEmpty)
        #expect(t.posture == .lying)
    }

    @Test("upright time counts only after having lain down")
    func uprightAfterLying() {
        var t = PostureTracker(holdMs: 60_000)
        _ = t.add(seconds(.upright, fromMs: 0, count: 600))
        #expect(t.posture == .upright)
        #expect(t.uprightAfterLyingMs == 0, "sitting up in bed before lying down")
        _ = t.add(seconds(.lying, fromMs: 600_000, count: 3600))
        _ = t.add(seconds(.upright, fromMs: 4_200_000, count: 300))
        #expect(t.uprightAfterLyingMs == 300_000)
        _ = t.add(seconds(.lying, fromMs: 4_500_000, count: 60))
        #expect(t.uprightAfterLyingMs == 0, "back to bed")
    }
}
