/// What a `TrainingRunner` speaks on, like `PacerCueSink` for the chimes. `begin` and `end`
/// bracket a whole run, so the audio stays up (and a locked app awake) through silent steps.
@MainActor
public protocol TrainingVoice: AnyObject {
    func begin()
    /// Starts saying `text` without waiting for it to finish.
    func say(_ text: String)
    /// The run is over; release what `begin` acquired once the last line has been said.
    func end()
}
