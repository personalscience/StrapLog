import StrapLogCore
import Testing

@Suite("BuildStamp")
struct BuildStampTests {
    @Test("names version, build number and commit")
    func stamp() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
                                   "StrapLogCommit": "dd795a4-dirty"]
        #expect(BuildStamp.short(info) == "0.1.0 (1)")
        #expect(BuildStamp.full(info) == "0.1.0 (1) · dd795a4-dirty")
        #expect(BuildStamp.full([:]) == "? (?) · unstamped")
    }
}
