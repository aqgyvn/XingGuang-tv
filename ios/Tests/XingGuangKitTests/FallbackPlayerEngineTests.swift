import Combine
import UIKit
import XCTest
@testable import XingGuangKit

@MainActor
final class FallbackPlayerEngineTests: XCTestCase {
    func testRTSPSelectsVLCBeforeLoading() {
        let av = PlayerEngineStub(kind: .avPlayer)
        let vlc = PlayerEngineStub(kind: .vlc)
        let engine = FallbackPlayerEngine(preference: .automatic, avPlayer: av, vlc: vlc)

        engine.load(PlaybackRequest(url: "rtsp://example.com/live"))

        XCTAssertEqual(av.loadCount, 0)
        XCTAssertEqual(vlc.loadCount, 1)
        XCTAssertEqual(engine.kind, .vlc)
    }

    func testFormatFailureFallsBackOnlyOnce() {
        let av = PlayerEngineStub(kind: .avPlayer)
        let vlc = PlayerEngineStub(kind: .vlc)
        let engine = FallbackPlayerEngine(preference: .automatic, avPlayer: av, vlc: vlc)
        engine.load(PlaybackRequest(url: "https://example.com/video"))

        av.fail(category: .format)
        vlc.fail(category: .format)

        XCTAssertEqual(av.loadCount, 1)
        XCTAssertEqual(vlc.loadCount, 1)
        XCTAssertEqual(engine.kind, .vlc)
    }

    func testAuthenticationFailureDoesNotFallback() {
        let av = PlayerEngineStub(kind: .avPlayer)
        let vlc = PlayerEngineStub(kind: .vlc)
        let engine = FallbackPlayerEngine(preference: .automatic, avPlayer: av, vlc: vlc)
        engine.load(PlaybackRequest(url: "https://example.com/video.mp4"))

        av.fail(category: .authentication)

        XCTAssertEqual(vlc.loadCount, 0)
    }

    func testForcedAVPlayerDoesNotFallbackOnFormatFailure() {
        let av = PlayerEngineStub(kind: .avPlayer)
        let vlc = PlayerEngineStub(kind: .vlc)
        let engine = FallbackPlayerEngine(preference: .automatic, avPlayer: av, vlc: vlc)
        engine.load(PlaybackRequest(url: "https://example.com/video", enginePreference: .avPlayer))

        av.fail(category: .format)

        XCTAssertEqual(vlc.loadCount, 0)
        XCTAssertEqual(engine.kind, .avPlayer)
    }

    func testSessionSeeksAfterPlayerBecomesReady() async {
        let player = PlayerEngineStub(kind: .avPlayer)
        let session = PlayerSession(engine: player)
        let resumed = expectation(description: "resume seek forwarded")
        player.onSeek = { position in
            if position == 42 { resumed.fulfill() }
        }

        session.load(PlaybackRequest(url: "https://example.com/video.mp4"), resumeAt: 42)
        XCTAssertTrue(player.seekPositions.isEmpty)

        player.ready()
        await fulfillment(of: [resumed], timeout: 1)
        XCTAssertEqual(player.seekPositions, [42])
    }
}

private final class PlayerEngineStub: PlayerEngine {
    let kind: PlayerEngineKind
    let capabilities: Set<PlayerCapability> = []
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { PlayerTime() }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { Just(PlayerTime()).eraseToAnyPublisher() }
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private(set) var loadCount = 0
    private(set) var seekPositions: [TimeInterval] = []
    var onSeek: ((TimeInterval) -> Void)?

    init(kind: PlayerEngineKind) { self.kind = kind }
    func load(_ request: PlaybackRequest) { loadCount += 1 }
    func play() {}
    func pause() {}
    func seek(to position: TimeInterval) {
        seekPositions.append(position)
        onSeek?(position)
    }
    func setRate(_ rate: Float) {}
    func select(track: PlayerTrack?) {}
    func stop() {}
    func makePlayerViewController() -> UIViewController { UIViewController() }
    func startPictureInPicture() -> Bool { false }
    func dispose() {}
    func fail(category: PlayerFailureCategory) {
        stateSubject.send(.failed(PlayerFailure(category: category, message: "failed")))
    }
    func ready() { stateSubject.send(.ready(duration: 100)) }
}
