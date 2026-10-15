/// Whether the app is on screen. Logged as `foreground`/`background` events while recording,
/// so a gap can be matched against what iOS was doing to the app at the time.
public enum AppPhase: Sendable, Equatable {
    case foreground, background

    var eventKind: EventKind {
        switch self {
        case .foreground: .foreground
        case .background: .background
        }
    }
}
