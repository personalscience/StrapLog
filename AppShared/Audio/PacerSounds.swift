import AVFoundation
import StrapLogCore

/// Plays the pacer's turns as `PacerTone` bells on the shared `AudioRig`.
///
/// Holds the rig from the first audible cue until the pacer stops, so the engine keeps running
/// between tones, which is what lets cues continue on a locked phone. With the sound off nothing
/// is held, and turning it off mid-run lets go at the next turn, so the background audio mode
/// only ever runs while tones are audible (or another holder, like a spoken session, needs it).
@MainActor
final class PacerSounds: PacerCueSink {
    private struct ToneKey: Hashable {
        let inhaling: Bool
        let frames: Int
    }

    private let rig: AudioRig
    /// Sound whatever the Sound toggle says (a spoken training run sets it).
    var forceAudible = false
    /// Whether this sink holds the rig.
    private var holding = false
    /// The current pacer's two tones; emptied when it stops.
    private var tones: [ToneKey: AVAudioPCMBuffer] = [:]

    init(rig: AudioRig) {
        self.rig = rig
    }

    func cue(inhaling: Bool, lengthMs: Double) {
        guard forceAudible || UserDefaults.standard.bool(forKey: PacerSettings.soundKey) else {
            pacerDidStop()
            return
        }
        if !holding {
            rig.hold()
            holding = true
        }
        // A tone that can't play must never disturb the pacer or a recording, so failure is just
        // silence, and the next cue tries again from scratch.
        guard let player = try? rig.runningPlayer() else { return }
        player.scheduleBuffer(tone(inhaling: inhaling, seconds: lengthMs / 1000), at: nil, options: .interrupts)
        player.play()
    }

    func pacerDidStop() {
        tones = [:]
        guard holding else { return }
        holding = false
        rig.stopPlayer()
        rig.release()
    }

    private func tone(inhaling: Bool, seconds: Double) -> AVAudioPCMBuffer {
        let key = ToneKey(inhaling: inhaling, frames: PacerTone.frameCount(seconds: seconds))
        if let cached = tones[key] { return cached }
        let samples = PacerTone.samples(inhaling: inhaling, seconds: seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: rig.format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer {
            buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }
        tones[key] = buffer
        return buffer
    }
}
