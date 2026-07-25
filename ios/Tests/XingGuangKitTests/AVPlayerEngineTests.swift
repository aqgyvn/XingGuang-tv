import AVKit
import XCTest
@testable import XingGuangKit

@MainActor
final class AVPlayerEngineTests: XCTestCase {
    func testCapabilitiesMatchSystemPictureInPictureSupport() {
        let engine = AVPlayerEngine()
        defer { engine.dispose() }

        XCTAssertTrue(engine.capabilities.contains(.airPlay))
        XCTAssertTrue(engine.capabilities.contains(.backgroundAudio))
        XCTAssertTrue(engine.capabilities.contains(.trackSelection))
        XCTAssertEqual(
            engine.capabilities.contains(.pictureInPicture),
            AVPictureInPictureController.isPictureInPictureSupported()
        )
    }

    func testPlayerSurfaceControllerIsStable() {
        let engine = AVPlayerEngine()
        defer { engine.dispose() }

        XCTAssertTrue(engine.makePlayerViewController() === engine.makePlayerViewController())
    }

    func testPictureInPictureDoesNotStartWithoutMedia() {
        let engine = AVPlayerEngine()
        defer { engine.dispose() }

        XCTAssertFalse(engine.startPictureInPicture())
    }

    func testStopResetsPublishedState() {
        let engine = AVPlayerEngine()
        defer { engine.dispose() }

        engine.stop()

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.time, PlayerTime())
        XCTAssertTrue(engine.tracks.isEmpty)
    }
}
