import AVFoundation
import StrapLogCore

/// Speaks a `TrainingRunner`'s lines with `AVSpeechSynthesizer` on the shared `AudioRig`.
///
/// Holds the rig from `begin` until the last line has been said after `end`, so the engine
/// keeps running, and a locked app awake, through silent steps and holds (the chimes' own hold
/// ends at every `pacerDidStop`). The synthesizer uses the app's session (`.playback`,
/// `.mixWithOthers`). No ducking: the lead-in already keeps voice and chimes apart.
///
/// Chimes must sound during a run whatever the Sound toggle says, so it sets
/// `PacerSounds.forceAudible` between `begin` and `end`; the user's setting is never written.
@MainActor
final class SpokenTraining: NSObject, TrainingVoice {
    private let rig: AudioRig
    private let sounds: PacerSounds
    private let synthesizer = AVSpeechSynthesizer()
    private var holding = false
    /// `end` was called; release the rig once the synthesizer goes quiet.
    private var ending = false

    init(rig: AudioRig, sounds: PacerSounds) {
        self.rig = rig
        self.sounds = sounds
        super.init()
        synthesizer.delegate = self
    }

    func begin() {
        ending = false
        sounds.forceAudible = true
        if !holding {
            rig.hold()
            holding = true
        }
        // Start the engine now: it is what keeps the app running while nothing sounds.
        _ = try? rig.runningPlayer()
    }

    func say(_ text: String) {
        // Rebuilds the engine and session if the system took them (a call, AirPods reconnecting).
        _ = try? rig.runningPlayer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func end() {
        sounds.forceAudible = false
        ending = true
        releaseIfQuiet()
    }

    private func releaseIfQuiet() {
        guard ending, holding, !synthesizer.isSpeaking else { return }
        ending = false
        holding = false
        rig.release()
    }
}

extension SpokenTraining: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseIfQuiet() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseIfQuiet() }
    }
}
