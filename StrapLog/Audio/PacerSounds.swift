import AVFoundation
import StrapLogCore

/// Plays the pacer's turns as `PacerTone` bells. The only file that imports AVFoundation.
///
/// The audio session stays active and the engine running between tones while the sound is on,
/// which is what lets cues continue on a locked phone. `.playback` because `.ambient` is muted
/// by the silent switch and gets no background time; `.mixWithOthers` so Music keeps playing.
/// With the sound off nothing is acquired, and turning it off mid-run releases it at the next
/// turn, so the background audio mode only ever runs while tones are audible.
///
/// The system can take the audio away mid-run: an interruption (a call, Siri, another app), an
/// engine configuration change (AirPods connecting), a media-services reset. Each marks the rig
/// stale, and the next cue rebuilds the engine and reactivates the session, so the sound comes
/// back by itself instead of staying silent until the app is relaunched.
@MainActor
final class PacerSounds: PacerCueSink {
    private struct Rig {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
    }

    private struct ToneKey: Hashable {
        let inhaling: Bool
        let frames: Int
    }

    private let format = AVAudioFormat(standardFormatWithSampleRate: PacerTone.sampleRate, channels: 1)!
    /// Built at the first audible cue, never at launch: most launches, and every Bluetooth
    /// restoration launch, have no use for audio.
    private var rig: Rig?
    /// The system stopped or reconfigured audio under us since the rig was built.
    private var stale = false
    /// The session was activated by us and not yet released.
    private var acquired = false
    private var observers: [NSObjectProtocol] = []
    /// The current pacer's two tones; emptied when it stops.
    private var tones: [ToneKey: AVAudioPCMBuffer] = [:]

    func cue(inhaling: Bool, lengthMs: Double) {
        guard UserDefaults.standard.bool(forKey: PacerSettings.soundKey) else {
            pacerDidStop()
            return
        }
        // A tone that can't play must never disturb the pacer or a recording, so failure is just
        // silence, and the next cue tries again from scratch.
        guard let player = try? runningPlayer() else { return }
        player.scheduleBuffer(tone(inhaling: inhaling, seconds: lengthMs / 1000), at: nil, options: .interrupts)
        player.play()
    }

    func pacerDidStop() {
        tearDown()
        tones = [:]
        guard acquired else { return }
        acquired = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The player on a running engine with the session active, rebuilt if anything was lost.
    private func runningPlayer() throws -> AVAudioPlayerNode {
        if let rig, rig.engine.isRunning, !stale { return rig.player }
        tearDown()
        stale = false
        observeSystemAudio()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.mixWithOthers])
        try session.setActive(true)
        acquired = true
        let built = Rig()
        built.engine.attach(built.player)
        built.engine.connect(built.player, to: built.engine.mainMixerNode, format: format)
        try built.engine.start()
        rig = built
        return built.player
    }

    private func tearDown() {
        guard let rig else { return }
        self.rig = nil
        rig.player.stop()
        rig.engine.stop()
    }

    private func observeSystemAudio() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Not routeChangeNotification: our own setCategory posts one, which would rebuild the rig
        // at every cue. A route change that matters (AirPods) also posts a configuration change.
        let names: [Notification.Name] = [AVAudioSession.interruptionNotification,
                                          AVAudioSession.mediaServicesWereResetNotification,
                                          .AVAudioEngineConfigurationChange]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stale = true }
            }
        }
    }

    private func tone(inhaling: Bool, seconds: Double) -> AVAudioPCMBuffer {
        let key = ToneKey(inhaling: inhaling, frames: PacerTone.frameCount(seconds: seconds))
        if let cached = tones[key] { return cached }
        let samples = PacerTone.samples(inhaling: inhaling, seconds: seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer {
            buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }
        tones[key] = buffer
        return buffer
    }
}
