import Combine
import UIKit
import XCTest
@testable import XingGuangKit

final class PlayerEngineFactoryTests: XCTestCase {
    func testFactoryCreatesOnlyRequestedEngine() {
        let factory = ClosurePlayerEngineFactory(
            mpv: { PlayerEngineStub(kind: .mpv) },
            mdk: { PlayerEngineStub(kind: .mdk) },
            avPlayer: { PlayerEngineStub(kind: .avPlayer) }
        )

        XCTAssertEqual(factory.makePlayer(preference: .mpv).kind, .mpv)
        XCTAssertEqual(factory.makePlayer(preference: .mdk).kind, .mdk)
        XCTAssertEqual(factory.makePlayer(preference: .avPlayer).kind, .avPlayer)
    }

    func testPlaybackRequestDefaultsToAVPlayer() {
        XCTAssertEqual(PlaybackRequest(url: "https://example.com/video.mp4").enginePreference, .avPlayer)
    }

    func testPreferenceOrderMatchesSettingsControl() {
        XCTAssertEqual(PlayerEnginePreference.allCases, [.mpv, .mdk, .avPlayer])
    }
}

private final class PlayerEngineStub: PlayerEngine {
    let kind: PlayerEngineKind
    let capabilities: Set<PlayerCapability> = []
    var state: PlayerState { .idle }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { PlayerTime() }
    var statePublisher: AnyPublisher<PlayerState, Never> { Just(.idle).eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { Just(PlayerTime()).eraseToAnyPublisher() }

    init(kind: PlayerEngineKind) { self.kind = kind }
    func load(_ request: PlaybackRequest) {}
    func play() {}
    func pause() {}
    func seek(to position: TimeInterval) {}
    func setRate(_ rate: Float) {}
    func select(track: PlayerTrack?) {}
    func stop() {}
    func makePlayerViewController() -> UIViewController { UIViewController() }
    func startPictureInPicture() -> Bool { false }
    func dispose() {}
}
