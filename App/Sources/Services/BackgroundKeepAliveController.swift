import AVFoundation

/// Resultado de intentar mantener la app activa en segundo plano.
enum BackgroundKeepAliveEvent: Equatable {
    /// El audio en silencio está sonando: iOS no suspenderá la app al bloquear la pantalla.
    case started
    /// No se pudo activar el audio: con la pantalla bloqueada iOS suspenderá la app.
    case failed
    /// El audio se cortó (llamada, otra app, reinicio de los servicios de audio) y se reanudó.
    case resumed
}

@MainActor
protocol BackgroundKeepAliveControlling: AnyObject {
    /// Se invoca en el hilo principal.
    var onEvent: ((BackgroundKeepAliveEvent) -> Void)? { get set }
    func setEnabled(_ enabled: Bool)
    /// Si está activado y el audio se detuvo sin aviso, lo vuelve a iniciar.
    func ensureRunning()
}

/// Mantiene la app en ejecución con la pantalla bloqueada reproduciendo audio en silencio,
/// una técnica que iOS permite con el modo de segundo plano `audio` declarado en Info.plist.
/// No requiere ningún permiso del usuario ni interrumpe la música de otras apps. Es experimental:
/// iOS puede detenerla y aumenta el consumo de batería.
@MainActor
final class BackgroundKeepAliveController: BackgroundKeepAliveControlling {
    private static let bufferDuration: Double = 1

    var onEvent: ((BackgroundKeepAliveEvent) -> Void)?

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
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
            onEvent?(startPlayback() ? .started : .failed)
        } else {
            stopPlayback()
            removeObservers()
        }
    }

    func ensureRunning() {
        guard isEnabled, !(engine.isRunning && player.isPlaying) else { return }
        restart()
    }

    /// Devuelve si el audio quedó sonando.
    @discardableResult
    private func startPlayback() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            guard let buffer = Self.makeSilentBuffer(format: format) else {
                stopPlayback()
                return false
            }
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            return engine.isRunning && player.isPlaying
        } catch {
            stopPlayback()
            return false
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

    /// Una llamada, otra app con audio exclusivo, un cambio de salida de audio o un reinicio de los servicios
    /// de audio detienen la reproducción; se reanuda en cuanto es posible.
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
                self?.restart()
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rebuildEngineAndRestart()
            }
        })
        observeEngineConfiguration()
    }

    private func observeEngineConfiguration() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restart()
            }
        })
    }

    private func restart() {
        guard isEnabled else { return }
        stopPlayback()
        onEvent?(startPlayback() ? .resumed : .failed)
    }

    /// Tras reiniciarse los servicios de audio, el motor anterior queda inservible y hay que crear otro.
    private func rebuildEngineAndRestart() {
        guard isEnabled else { return }
        player.stop()
        engine.stop()
        removeObservers()
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        observeAudioSession()
        onEvent?(startPlayback() ? .resumed : .failed)
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
