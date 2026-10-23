import Testing
@testable import StrapLogCore

@Suite("ActivityPreset")
struct ActivityPresetTests {
    @Test("ids and each preset's marker labels are unique; unknown ids fall back to other")
    func catalog() {
        #expect(Set(ActivityPreset.all.map(\.id)).count == ActivityPreset.all.count)
        for preset in ActivityPreset.all {
            #expect(Set(preset.markers).count == preset.markers.count, "\(preset.id)")
            #expect(ActivityPreset.named(preset.id) == preset)
        }
        #expect(ActivityPreset.named("ruck-from-a-newer-build") == .other)
    }

    @Test("sleep is overnight; other keeps the a b c end bar")
    func sleepFirst() {
        #expect(ActivityPreset.sleep.overnight && !ActivityPreset.other.overnight)
        #expect(ActivityPreset.other.markers == ["a", "b", "c", "end"])
    }

    @Test("default name uses the local date, not UTC")
    func defaultName() {
        // 2025-10-10 03:00 UTC is still Oct 9 at -7 h.
        #expect(ActivityPreset.sleep.defaultName(atMs: 1_760_065_200_000, tzOffsetS: -7 * 3600) == "sleep 2025-10-09")
        #expect(ActivityPreset.sleep.defaultName(atMs: 1_760_065_200_000, tzOffsetS: 0) == "sleep 2025-10-10")
    }
}
