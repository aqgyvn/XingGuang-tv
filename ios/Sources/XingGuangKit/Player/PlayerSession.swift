import Combine
import Foundation

public final class PlayerSession: ObservableObject {
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var time = PlayerTime()
    @Published public private(set) var tracks: [PlayerTrack] = []

    public let engine: PlayerEngine
    private var pendingResume: TimeInterval = 0
    private var resumeSubscription: AnyCancellable?

    public init(engine: PlayerEngine) {
        self.engine = engine
        engine.statePublisher.receive(on: DispatchQueue.main).assign(to: &$state)
        engine.timePublisher.receive(on: DispatchQueue.main).assign(to: &$time)
        engine.tracksPublisher.receive(on: DispatchQueue.main).assign(to: &$tracks)
    }

    public func load(_ request: PlaybackRequest, resumeAt position: TimeInterval = 0) {
        pendingResume = max(position, 0)
        resumeSubscription?.cancel()
        engine.load(request)
        guard pendingResume > 0 else { return }
        resumeSubscription = engine.statePublisher
            .filter { state in
                if case .ready = state { return true }
                return false
            }
            .prefix(1)
            .sink { [weak self] _ in
                guard let self, self.pendingResume > 0 else { return }
                self.engine.seek(to: self.pendingResume)
                self.pendingResume = 0
            }
    }

    public func togglePlayback() {
        if case .playing = state { engine.pause() } else { engine.play() }
    }

    public func stop() { engine.stop() }

    deinit { engine.dispose() }
}
