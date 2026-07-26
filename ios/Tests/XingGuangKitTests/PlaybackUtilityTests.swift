import Foundation
import XCTest
@testable import XingGuangKit

final class PlaybackUtilityTests: XCTestCase {
    func testEngineNamesMatchVisiblePlayerChoices() {
        XCTAssertEqual(PlayerEngineKind.mpv.displayName, "MPV")
        XCTAssertEqual(PlayerEngineKind.mdk.displayName, "MDK")
        XCTAssertEqual(PlayerEngineKind.avPlayer.displayName, "AVPlayer")
    }

    func testSharePayloadIncludesTitleAndURL() {
        let payload = PlaybackSharePayload(title: "节目", url: "https://example.com/live.m3u8")

        XCTAssertEqual(payload.activityItems.count, 2)
        XCTAssertEqual(payload.activityItems[0] as? String, "节目")
        XCTAssertEqual((payload.activityItems[1] as? URL)?.absoluteString, "https://example.com/live.m3u8")
    }

    func testPlaybackInformationHidesAuthenticationHeaders() {
        XCTAssertEqual(PlaybackInformationPrivacy.headerValue(key: "Cookie", value: "sid=secret"), "已隐藏")
        XCTAssertEqual(PlaybackInformationPrivacy.headerValue(key: "authorization", value: "Bearer secret"), "已隐藏")
        XCTAssertEqual(PlaybackInformationPrivacy.headerValue(key: "Referer", value: "https://example.com"), "https://example.com")
    }
}
