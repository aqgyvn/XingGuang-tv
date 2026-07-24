import UIKit
import XCTest

final class XingGuangUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testVodHomeStartsOnSupportedDevices() {
        XCTAssertTrue(app.descendants(matching: .any)["vod.home"].waitForExistence(timeout: 10))
    }

    func testPrimaryTabsAndConfigurationSaveOnIPhone() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The iPad TabView does not expose labeled tab buttons to this XCTest runtime")

        XCTAssertTrue(app.tabBars.buttons["点播"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["直播"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.home"].waitForExistence(timeout: 5))

        let vodField = app.textFields["点播配置"]
        XCTAssertTrue(vodField.waitForExistence(timeout: 5))
        vodField.tap()
        vodField.typeText("https://example.com/vod.json")
        app.buttons["settings.save"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings.saved"].waitForExistence(timeout: 5))
    }

    func testVodDetailNavigation() {
        XCTAssertTrue(app.descendants(matching: .any)["vod.home"].waitForExistence(timeout: 10))
        app.staticTexts["少侠逆袭攻略"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["vod.detail"].waitForExistence(timeout: 5))
    }
}
