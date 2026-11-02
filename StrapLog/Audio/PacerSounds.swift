import AVFoundation
import StrapLogCore

/// Plays the pacer's turns as `PacerTone`s. The only file that imports AVFoundation.
///
/// The audio session stays active and the engine running between tones while the sound is on,
/// which is what lets cues continue on a locked phone. `.playback` because `.ambient` is muted
/// by the silent switch and gets no background time; `.mixWithOthers` so Music keeps playing.
/// With the sound off nothing is acquired, and turning it off mid-run releases it at the next
/// turn, so the background audio mode only ever runs while tones are audible.
@MainActor
final class PacerSounds: PacerCueSink {
    /// Built at the first audible cue, never at launch: most launches, and every Bluetooth
    /// restoration launch, have no use for audio.
    private lazy var engine = makeEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: PacerTone.sampleRate, channels: 1)!
    private lazy var inhale = buffer(PacerTone.samples(inhaling: true))
    private lazy var exhale = buffer(PacerTone.samples(inhaling: false))
    private var acquired = false

    func cue(inhaling: Bool) {
        guard UserDefaults.standard.bool(forKey: PacerSettings.soundKey) else {
            pacerDidStop()
            return
        }
        // Checked on every cue: an interruption or route change stops the engine under us. A tone
        // that can't play must never disturb the pacer or a recording, so failure is just silence.
        do {
            if !acquired {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: [.mixWithOthers])
                try session.setActive(true)
                acquired = true
            }
            if !engine.isRunning { try engine.start() }
        } catch {
            return
        }
        player.scheduleBuffer(inhaling ? inhale : exhale, at: nil, options: .interrupts)
        player.play()
    }

    func pacerDidStop() {
        guard acquired else { return }
        acquired = false
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer {
            buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }
        return buffer
    }

    private func makeEngine() -> AVAudioEngine {
        let engine = AVAudioEngine()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        return engine
    }
}
