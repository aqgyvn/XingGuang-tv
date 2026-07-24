import Combine
import UIKit

public final class PreviewPlayerEngineFactory: PlayerEngineFactory, @unchecked Sendable {
    public init() {}
    public func makePlayer(preference: PlayerEnginePreference) -> PlayerEngine { PreviewPlayerEngine() }
}

public final class PreviewPlayerEngine: PlayerEngine {
    public let kind: PlayerEngineKind = .avPlayer
    public let capabilities: Set<PlayerCapability> = []
    public var state: PlayerState { stateSubject.value }
    public var tracks: [PlayerTrack] { [] }
    public var time: PlayerTime { timeSubject.value }
    public var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    public var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    public var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())

    public init() {}
    public func load(_ request: PlaybackRequest) { stateSubject.send(.ready(duration: 2700)) }
    public func play() { stateSubject.send(.playing) }
    public func pause() { stateSubject.send(.paused) }
    public func seek(to position: TimeInterval) { timeSubject.send(PlayerTime(position: position, duration: 2700, buffered: position)) }
    public func setRate(_ rate: Float) {}
    public func select(track: PlayerTrack?) {}
    public func stop() { stateSubject.send(.idle) }
    public func makePlayerViewController() -> UIViewController { PreviewPlayerViewController() }
    public func startPictureInPicture() -> Bool { false }
    public func release() {}
}

private final class PreviewPlayerViewController: UIViewController {
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}
