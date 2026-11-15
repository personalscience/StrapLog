import AVFoundation

/// The app's audio output: the session, one running engine with one player node, and the
/// observers that notice when the system takes the audio away. Shared by everything that
/// sounds (`PacerSounds`, and ArmLog's spoken training), and held by count: the engine runs
/// while anyone holds the rig, and the session is released when the last holder lets go.
///
/// A running engine is what keeps a locked app alive between sounds, so a holder that needs
/// to stay awake through silence (a spoken session's quiet steps) just keeps holding.
///
/// `.playback` because `.ambient` is muted by the silent switch and gets no background time;
/// `.mixWithOthers` so Music keeps playing. Built at the first `runningPlayer`, never at launch:
/// most launches, and every Bluetooth restoration launch, have no use for audio.
///
/// The system can take the audio away mid-run: an interruption (a call, Siri, another app), an
/// engine configuration change (AirPods connecting), a media-services reset. Each marks the rig
/// stale, and the next `runningPlayer` rebuilds the engine and reactivates the session, so the
/// sound comes back by itself instead of staying silent until the app is relaunched.
@MainActor
final class AudioRig {
    private struct Engine {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
    }

    /// The player's format: `PacerTone`'s mono stream.
    let format = AVAudioFormat(standardFormatWithSampleRate: PacerTone.sampleRate, channels: 1)!
    private var built: Engine?
    /// The system stopped or reconfigured audio under us since the engine was built.
    private var stale = false
    /// The session was activated by us and not yet released.
    private var acquired = false
    private var holders = 0
    private var observers: [NSObjectProtocol] = []

    /// Counts a holder. Builds nothing: `runningPlayer` does.
    func hold() {
        holders += 1
    }

    /// Lets go of one `hold`; the last release stops the engine and releases the session.
    func release() {
        guard holders > 0 else { return }
        holders -= 1
        guard holders == 0 else { return }
        tearDown()
        guard acquired else { return }
        acquired = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Silences whatever the player has scheduled, leaving the engine running for other holders.
    func stopPlayer() {
        built?.player.stop()
    }

    /// The player on a running engine with the session active, rebuilt if anything was lost.
    /// Call only while holding the rig.
    func runningPlayer() throws -> AVAudioPlayerNode {
        if let built, built.engine.isRunning, !stale { return built.player }
        tearDown()
        stale = false
        observeSystemAudio()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, options: [.mixWithOthers])
        try session.setActive(true)
        acquired = true
        let fresh = Engine()
        fresh.engine.attach(fresh.player)
        fresh.engine.connect(fresh.player, to: fresh.engine.mainMixerNode, format: format)
        try fresh.engine.start()
        built = fresh
        return fresh.player
    }

    private func tearDown() {
        guard let built else { return }
        self.built = nil
        built.player.stop()
        built.engine.stop()
    }

    private func observeSystemAudio() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Not routeChangeNotification: our own setCategory posts one, which would rebuild the
        // engine at every use. A route change that matters (AirPods) also posts a configuration change.
        let names: [Notification.Name] = [AVAudioSession.interruptionNotification,
                                          AVAudioSession.mediaServicesWereResetNotification,
                                          .AVAudioEngineConfigurationChange]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stale = true }
            }
        }
    }
}
