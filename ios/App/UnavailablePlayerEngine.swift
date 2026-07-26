import Combine
import UIKit
import XingGuangKit

class UnavailablePlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind
    let capabilities: Set<PlayerCapability> = []
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { PlayerTime() }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { Just(PlayerTime()).eraseToAnyPublisher() }

    private let message: String
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)

    init(kind: PlayerEngineKind, message: String) {
        self.kind = kind
        self.message = message
    }

    func load(_ request: PlaybackRequest) {
        stateSubject.send(.failed(PlayerFailure(category: .format, message: message)))
    }
    func play() {}
    func pause() {}
    func seek(to position: TimeInterval) {}
    func setRate(_ rate: Float) {}
    func select(track: PlayerTrack?) {}
    func stop() { stateSubject.send(.idle) }
    func makePlayerViewController() -> UIViewController { UIViewController() }
    func startPictureInPicture() -> Bool { false }
    func dispose() {}
}
