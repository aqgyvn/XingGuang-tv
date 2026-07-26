import Combine
import Foundation

public final class PlayerSession: ObservableObject {
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var time = PlayerTime()
    @Published public private(set) var tracks: [PlayerTrack] = []
    @Published public var loopEnabled = false
    @Published public private(set) var sleepTimerRemaining = 0

    public let engine: PlayerEngine
    public var kind: PlayerEngineKind { engine.kind }
    public var capabilities: Set<PlayerCapability> { engine.capabilities }
    public var loopStart: TimeInterval = 0
    private var pendingResume: TimeInterval = 0
    private var preferredRate: Float = 1
    private var resumeSubscription: AnyCancellable?
    private var rateSubscription: AnyCancellable?
    private var loopSubscription: AnyCancellable?
    private var sleepTimer: Timer?
    private var sleepTimerDeadline: Date?

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
        loopSubscription = engine.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.loopEnabled else { return }
                if case .ended = state { self.replay(from: self.loopStart) }
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

    public func replay(from position: TimeInterval = 0) {
        seek(to: position)
        engine.play()
    }

    public func setSleepTimer(minutes: Int) {
        setSleepTimer(after: TimeInterval(max(minutes, 0) * 60))
    }

    public func extendSleepTimer(minutes: Int = 5) {
        let remaining = max(sleepTimerDeadline?.timeIntervalSinceNow ?? 0, 0)
        setSleepTimer(after: remaining + TimeInterval(max(minutes, 0) * 60))
    }

    public func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerDeadline = nil
        sleepTimerRemaining = 0
    }

    func setSleepTimer(after duration: TimeInterval) {
        cancelSleepTimer()
        guard duration > 0 else { return }
        sleepTimerDeadline = Date().addingTimeInterval(duration)
        updateSleepTimer()
        let interval = min(max(duration, 0.01), 1)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateSleepTimer()
        }
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

    private func updateSleepTimer() {
        guard let deadline = sleepTimerDeadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            cancelSleepTimer()
            engine.pause()
            return
        }
        sleepTimerRemaining = Int(remaining.rounded(.up))
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

    deinit {
        sleepTimer?.invalidate()
        engine.dispose()
    }
}
