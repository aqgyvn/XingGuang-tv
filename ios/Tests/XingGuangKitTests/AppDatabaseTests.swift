import XCTest
@testable import XingGuangKit

final class AppDatabaseTests: XCTestCase {
    func testPathInitializerCreatesUsableDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase(path: directory.appendingPathComponent("xingguang.sqlite").path)

        XCTAssertFalse(try database.containsKeep(key: "missing"))
    }

    func testKeepToggleAndHistoryRoundTrip() throws {
        let database = try AppDatabase.inMemory()
        let keep = Keep(key: "site@@@1", siteName: "站点", vodName: "影片", createTime: 10)

        XCTAssertTrue(try database.toggleKeep(keep))
        XCTAssertEqual(try database.loadKeeps().first?.vodName, "影片")
        XCTAssertFalse(try database.toggleKeep(keep))

        var history = History(key: "site@@@1", vodName: "影片")
        history.episodeURL = "https://example.com/1.m3u8"
        history.position = 12_000
        history.duration = 60_000
        history.createTime = 20
        try database.saveHistory(history)

        XCTAssertEqual(try database.history(key: history.key)?.position, 12_000)
    }

    func testConfigurationReplacementIsAtomicAndPersistsSites() throws {
        let database = try AppDatabase.inMemory()
        let document = VodConfigDocument(sites: [Site(key: "api", name: "接口", api: "https://example.com", type: 1)])

        try database.replaceConfiguration(document, sourceURL: "https://example.com/config.json")

        XCTAssertEqual(try database.loadSites().map(\.key), ["api"])
    }
}
