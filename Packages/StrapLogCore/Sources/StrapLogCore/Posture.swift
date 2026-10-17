/// Torso posture from the strap's gravity vector. Stored as the note of `posture` events.
///
/// The H10's x axis runs along the spine, so |gx| / |g| is the cosine of the torso's tilt from
/// vertical. On Rik's first device night (2026-10-15) every lying position stayed at or below
/// 0.36 (pillow-propped side-lying), while sitting and standing ran 0.45–0.9. Using |gx| keeps
/// the call the same if the strap is worn upside down.
public enum Posture: String, Sendable, Equatable {
    case upright, lying

    /// |gx| / |g| at or above this is upright: torso within ~53° of vertical.
    public static let uprightCosine = 0.6
    /// A mean gravity vector shorter than this (mg) is too disturbed to classify.
    static let minGravityMg = 500.0

    /// The posture of one second, or nil if it has no usable gravity vector.
    public static func of(_ second: MotionSecond) -> Posture? {
        let g = (second.gxMg * second.gxMg + second.gyMg * second.gyMg + second.gzMg * second.gzMg).squareRoot()
        guard second.n > 0, g >= minGravityMg else { return nil }
        return abs(second.gxMg) / g >= uprightCosine ? .upright : .lying
    }
}
