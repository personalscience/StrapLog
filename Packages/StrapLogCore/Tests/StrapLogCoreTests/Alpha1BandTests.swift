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

    @Test("bounds tile 0…∞ with no gaps, and each band contains its own lower bound")
    func bounds() {
        let bands = Alpha1Band.allCases
        #expect(bands.last?.lowerBound == 0)
        #expect(bands.first?.upperBound == .infinity)
        for (higher, lower) in zip(bands, bands.dropFirst()) { #expect(lower.upperBound == higher.lowerBound) }
        for band in bands { #expect(Alpha1Band(alpha1: band.lowerBound) == band) }
        #expect(Alpha1Band(alpha1: -0.1) == .veryHard)
    }
}
