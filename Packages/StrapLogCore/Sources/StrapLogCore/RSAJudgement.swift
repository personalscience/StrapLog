import HRVKit

/// How the fitted HR peak sits against `RSADefaults.peakTargetFraction` (0.6 of the breath, Rik's
/// own followed 6/min steps), for the peak line's colour. With too little sync there is no
/// rhythm whose peak could be judged.
public enum RSAJudgement: Sendable, Equatable {
    /// Within `peakGreenBand` of the target.
    case onTarget
    /// Within `peakAmberBand`.
    case near
    case off
    /// Sync under `minSync`.
    case noRhythm

    /// Below this, HR is not following the pacer: the holds and the wrong-rate fits on the
    /// 261115 fixture read 0.1–0.3, the followed steps 0.6–0.9.
    public static let minSync = 0.3

    public init(_ fit: CosinorFit) {
        guard fit.sync >= Self.minSync else { self = .noRhythm; return }
        let d = abs(fit.peakFraction - RSADefaults.peakTargetFraction)
        let distance = min(d, 1 - d)
        self = distance <= RSADefaults.peakGreenBand ? .onTarget
            : distance <= RSADefaults.peakAmberBand ? .near : .off
    }
}
