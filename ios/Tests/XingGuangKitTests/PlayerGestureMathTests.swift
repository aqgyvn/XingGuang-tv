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
}
