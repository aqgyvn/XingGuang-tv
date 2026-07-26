import XCTest
@testable import XingGuangKit

final class PlayerGestureMathTests: XCTestCase {
    func testHorizontalSeekClampsToMediaBounds() {
        XCTAssertEqual(PlayerGestureMath.seekTarget(initial: 30, translation: 100, duration: 120), 35)
        XCTAssertEqual(PlayerGestureMath.seekTarget(initial: 2, translation: -100, duration: 120), 0)
        XCTAssertEqual(PlayerGestureMath.seekTarget(initial: 118, translation: 100, duration: 120), 120)
    }

    func testPinchZoomClampsBetweenOneAndFive() {
        XCTAssertEqual(PlayerGestureMath.zoomScale(current: 2, delta: 1.5), 3)
        XCTAssertEqual(PlayerGestureMath.zoomScale(current: 1, delta: 0.2), 1)
        XCTAssertEqual(PlayerGestureMath.zoomScale(current: 4, delta: 2), 5)
    }

    func testCenterGestureRegionUsesMiddleHalf() {
        XCTAssertFalse(PlayerGestureMath.isCenter(startX: 24, width: 100))
        XCTAssertTrue(PlayerGestureMath.isCenter(startX: 25, width: 100))
        XCTAssertTrue(PlayerGestureMath.isCenter(startX: 75, width: 100))
        XCTAssertFalse(PlayerGestureMath.isCenter(startX: 76, width: 100))
    }

    func testVerticalSwipeRequiresDistanceAndDirection() {
        XCTAssertEqual(PlayerGestureMath.verticalSwipeDirection(translation: CGSize(width: 10, height: -120)), -1)
        XCTAssertEqual(PlayerGestureMath.verticalSwipeDirection(translation: CGSize(width: 10, height: 120)), 1)
        XCTAssertNil(PlayerGestureMath.verticalSwipeDirection(translation: CGSize(width: 10, height: 99)))
        XCTAssertNil(PlayerGestureMath.verticalSwipeDirection(translation: CGSize(width: 120, height: 100)))
    }

    func testEpisodeSwipeFollowsDisplayedSortOrder() {
        XCTAssertEqual(PlayerGestureMath.episodeOffset(forward: true, reverse: false), 1)
        XCTAssertEqual(PlayerGestureMath.episodeOffset(forward: false, reverse: false), -1)
        XCTAssertEqual(PlayerGestureMath.episodeOffset(forward: true, reverse: true), -1)
        XCTAssertEqual(PlayerGestureMath.episodeOffset(forward: false, reverse: true), 1)
    }
}
