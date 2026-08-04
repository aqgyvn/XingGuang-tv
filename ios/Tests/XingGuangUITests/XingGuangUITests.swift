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
        XCTAssertTrue(app.buttons["settings.vod.open"].exists)
        XCTAssertTrue(app.buttons["settings.live.open"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.vod.home"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.live.home"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.vod.history"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.live.history"].exists)
        XCTAssertTrue(app.buttons["settings.player.open"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.catalogDisplaySize"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.incognito"].exists)
        XCTAssertTrue(app.buttons["settings.cache.clear"].exists)
        XCTAssertTrue(app.buttons["settings.vod.open"].waitForExistence(timeout: 5))
        app.buttons["settings.vod.open"].tap()
        XCTAssertTrue(app.buttons["settings.vod.file"].exists)
        XCTAssertTrue(app.buttons["settings.vod.scan"].exists)

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

    func testPlayerSettingsControlsOnIPhone() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "The iPad TabView does not expose labeled tab buttons to this XCTest runtime")

        app.tabBars.buttons["设置"].tap()
        let playerSettings = app.buttons["settings.player.open"]
        XCTAssertTrue(playerSettings.waitForExistence(timeout: 5))
        playerSettings.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings.player.engine"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.player.longPressSpeed"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.player.danmakuLoad"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.player.userAgent"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.player.adHostBlocking"].exists)
    }
}
