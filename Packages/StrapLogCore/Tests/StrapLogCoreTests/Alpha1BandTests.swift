import Testing
@testable import StrapLogCore

@Suite("Alpha1Band")
struct Alpha1BandTests {
    @Test("α1 bands cut at 1.0, 0.75, 0.50")
    func bands() {
        #expect(Alpha1Band(alpha1: 1.3) == .rest)
        #expect(Alpha1Band(alpha1: 1.0) == .rest)
        #expect(Alpha1Band(alpha1: 0.99) == .easy)
        #expect(Alpha1Band(alpha1: 0.75) == .easy)
        #expect(Alpha1Band(alpha1: 0.7499) == .moderate)
        #expect(Alpha1Band(alpha1: 0.5) == .moderate)
        #expect(Alpha1Band(alpha1: 0.49) == .veryHard)
    }
}
