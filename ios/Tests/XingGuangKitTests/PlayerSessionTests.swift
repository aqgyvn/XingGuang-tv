import Combine
import UIKit
import XCTest
@testable import XingGuangKit

@MainActor
final class PlayerSessionTests: XCTestCase {
    func testSynchronousReadyLoadRestoresPosition() {
        let engine = SessionPlayerEngineStub(loadState: .ready(duration: 120))
        let session = PlayerSession(engine: engine)

        session.load(PlaybackRequest(url: "https://example.com/video.mp4"), resumeAt: 42)

        XCTAssertEqual(engine.seekPositions, [42])
    }

    func testStopCancelsPendingResume() {
        let engine = SessionPlayerEngineStub(loadState: .loading)
        let session = PlayerSession(engine: engine)

        session.load(PlaybackRequest(url: "https://example.com/video.mp4"), resumeAt: 42)
        session.stop()
        engine.send(.ready(duration: 120))

        XCTAssertTrue(engine.seekPositions.isEmpty)
    }

    func testPlayingStateRestoresPositionForThirdPartyEngine() async {
        let engine = SessionPlayerEngineStub(loadState: .loading)
        let session = PlayerSession(engine: engine)
        let resumed = expectation(description: "resume seek forwarded")
        engine.onSeek = { position in
            if position == 27 { resumed.fulfill() }
        }

        session.load(PlaybackRequest(url: "https://example.com/video.mkv"), resumeAt: 27)
        engine.send(.playing)
        await fulfillment(of: [resumed], timeout: 1)

        XCTAssertEqual(engine.seekPositions, [27])
    }

    func testSessionForwardsPlaybackControls() {
        let track = PlayerTrack(id: "audio:1", kind: .audio, name: "Stereo")
        let engine = SessionPlayerEngineStub(loadState: .loading)
        let session = PlayerSession(engine: engine)

        session.seek(to: 18)
        session.setRate(1.5)
        session.select(track: track)

        XCTAssertEqual(engine.seekPositions, [18])
        XCTAssertEqual(engine.rates, [1.5])
        XCTAssertEqual(engine.selectedTrack, track)
    }

    func testSessionSanitizesInvalidPlaybackControls() {
        let engine = SessionPlayerEngineStub(loadState: .loading)
        let session = PlayerSession(engine: engine)

        session.seek(to: .nan)
        session.setRate(.nan)

        XCTAssertEqual(engine.seekPositions, [0])
        XCTAssertEqual(engine.rates, [1])
    }

    func testPreferredRateIsReappliedWhenEngineStartsPlaying() async {
        let engine = SessionPlayerEngineStub(loadState: .loading)
        let session = PlayerSession(engine: engine)

        session.setRate(1.5)
        let reapplied = expectation(description: "preferred rate reapplied")
        engine.onRate = { rate in
            if rate == 1.5, engine.rates.count == 2 { reapplied.fulfill() }
        }
        engine.send(.playing)
        await fulfillment(of: [reapplied], timeout: 1)

        XCTAssertEqual(engine.rates, [1.5, 1.5])
    }

    func testSessionExposesEngineMetadataAndForwardsPictureInPicture() {
        let engine = SessionPlayerEngineStub(
            loadState: .loading,
            kind: .mpv,
            capabilities: [.pictureInPicture, .trackSelection],
            pictureInPictureResult: true
        )
        let session = PlayerSession(engine: engine)

        XCTAssertEqual(session.kind, .mpv)
        XCTAssertEqual(session.capabilities, [.pictureInPicture, .trackSelection])
        XCTAssertTrue(session.startPictureInPicture())
        XCTAssertEqual(engine.pictureInPictureCallCount, 1)
    }
}

private final class SessionPlayerEngineStub: PlayerEngine {
    let kind: PlayerEngineKind
    let capabilities: Set<PlayerCapability>
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { PlayerTime() }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { Just(PlayerTime()).eraseToAnyPublisher() }

    private let loadState: PlayerState
    private let pictureInPictureResult: Bool
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private(set) var seekPositions: [TimeInterval] = []
    private(set) var rates: [Float] = []
    private(set) var selectedTrack: PlayerTrack?
    private(set) var pictureInPictureCallCount = 0
    var onSeek: ((TimeInterval) -> Void)?
    var onRate: ((Float) -> Void)?

    init(
        loadState: PlayerState,
        kind: PlayerEngineKind = .avPlayer,
        capabilities: Set<PlayerCapability> = [.trackSelection],
        pictureInPictureResult: Bool = false
    ) {
        self.loadState = loadState
        self.kind = kind
        self.capabilities = capabilities
        self.pictureInPictureResult = pictureInPictureResult
    }

    func load(_ request: PlaybackRequest) { stateSubject.send(loadState) }
    func play() { stateSubject.send(.playing) }
    func pause() { stateSubject.send(.paused) }
    func seek(to position: TimeInterval) {
        seekPositions.append(position)
        onSeek?(position)
    }
    func setRate(_ rate: Float) {
        rates.append(rate)
        onRate?(rate)
    }
    func select(track: PlayerTrack?) { selectedTrack = track }
    func stop() { stateSubject.send(.idle) }
    func makePlayerViewController() -> UIViewController { UIViewController() }
    func startPictureInPicture() -> Bool {
        pictureInPictureCallCount += 1
        return pictureInPictureResult
    }
    func dispose() {}
    func send(_ state: PlayerState) { stateSubject.send(state) }
}
