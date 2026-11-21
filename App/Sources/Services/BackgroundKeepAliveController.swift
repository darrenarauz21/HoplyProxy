import AVFoundation

@MainActor
protocol BackgroundKeepAliveControlling: AnyObject {
    func setEnabled(_ enabled: Bool)
}

/// Mantiene la app en ejecución con la pantalla bloqueada reproduciendo audio en silencio,
/// una técnica que iOS permite con el modo de segundo plano `audio`. No interrumpe la música
/// de otras apps. Es experimental: iOS puede detenerla y aumenta el consumo de batería.
@MainActor
final class BackgroundKeepAliveController: BackgroundKeepAliveControlling {
    private static let bufferDuration: Double = 1

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isEnabled = false
    private var observers: [NSObjectProtocol] = []

    init() {
        engine.attach(player)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            observeAudioSession()
            startPlayback()
        } else {
            stopPlayback()
            removeObservers()
        }
    }

    private func startPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            guard let buffer = Self.makeSilentBuffer(format: format) else { return }
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
        } catch {
            // Sin audio la app sigue funcionando en primer plano; no hay nada más que hacer.
            stopPlayback()
        }
    }

    private func stopPlayback() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func makeSilentBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate * bufferDuration)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                channels[channel].update(repeating: 0, count: Int(frameCount))
            }
        }
        return buffer
    }

    /// Una llamada u otra app con audio exclusivo interrumpe la reproducción; se reanuda al terminar.
    private func observeAudioSession() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended else { return }
            Task { @MainActor [weak self] in
                self?.restartIfEnabled()
            }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restartIfEnabled()
            }
        })
    }

    private func restartIfEnabled() {
        guard isEnabled else { return }
        stopPlayback()
        startPlayback()
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
