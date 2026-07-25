import Combine
import Foundation

public final class PlayerSession: ObservableObject {
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var time = PlayerTime()
    @Published public private(set) var tracks: [PlayerTrack] = []

    public let engine: PlayerEngine
    public var kind: PlayerEngineKind { engine.kind }
    public var capabilities: Set<PlayerCapability> { engine.capabilities }
    private var pendingResume: TimeInterval = 0
    private var preferredRate: Float = 1
    private var resumeSubscription: AnyCancellable?
    private var rateSubscription: AnyCancellable?

    public init(engine: PlayerEngine) {
        self.engine = engine
        engine.statePublisher.receive(on: DispatchQueue.main).assign(to: &$state)
        engine.timePublisher.receive(on: DispatchQueue.main).assign(to: &$time)
        engine.tracksPublisher.receive(on: DispatchQueue.main).assign(to: &$tracks)
        rateSubscription = engine.statePublisher
            .receive(on: DispatchQueue.main)
            .filter { state in
                switch state {
                case .ready, .playing: return true
                default: return false
                }
            }
            .sink { [weak self] _ in
                guard let self else { return }
                self.engine.setRate(self.preferredRate)
            }
    }

    public func load(_ request: PlaybackRequest, resumeAt position: TimeInterval = 0) {
        resumeSubscription?.cancel()
        resumeSubscription = nil
        pendingResume = 0
        engine.load(request)
        pendingResume = position.isFinite ? max(position, 0) : 0
        guard pendingResume > 0 else { return }
        if canApplyResume(engine.state) {
            applyPendingResume()
            return
        }
        resumeSubscription = engine.statePublisher
            .receive(on: DispatchQueue.main)
            .filter { [weak self] state in self?.canApplyResume(state) == true }
            .prefix(1)
            .sink { [weak self] _ in
                self?.applyPendingResume()
            }
    }

    public func togglePlayback() {
        if case .playing = state { engine.pause() } else { engine.play() }
    }

    public func seek(to position: TimeInterval) {
        engine.seek(to: position.isFinite ? max(position, 0) : 0)
    }

    public func setRate(_ rate: Float) {
        preferredRate = rate.isFinite ? max(rate, 0.1) : 1
        engine.setRate(preferredRate)
    }

    public func select(track: PlayerTrack?) {
        engine.select(track: track)
    }

    @discardableResult
    public func startPictureInPicture() -> Bool {
        engine.startPictureInPicture()
    }

    public func stop() {
        resumeSubscription?.cancel()
        resumeSubscription = nil
        pendingResume = 0
        engine.stop()
    }

    private func applyPendingResume() {
        guard pendingResume > 0 else { return }
        let position = pendingResume
        pendingResume = 0
        resumeSubscription?.cancel()
        resumeSubscription = nil
        engine.seek(to: position)
    }

    private func canApplyResume(_ state: PlayerState) -> Bool {
        switch state {
        case .ready, .playing, .paused: return true
        default: return false
        }
    }

    deinit { engine.dispose() }
}
