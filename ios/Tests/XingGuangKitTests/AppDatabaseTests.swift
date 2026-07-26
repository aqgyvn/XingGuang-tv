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

    func testValidatedBackupReplacesCollectionsAndAppliesPreferences() throws {
        let database = try AppDatabase.inMemory()
        try database.replaceConfiguration(
            VodConfigDocument(sites: [Site(key: "old", name: "Old", api: "https://old.example", type: 1)]),
            sourceURL: "https://old.example/config.json"
        )
        let oldKeep = Keep(key: "old@@@1", vodName: "old")
        try database.toggleKeep(oldKeep)

        var oldHistory = History(key: "old@@@1", vodName: "old")
        oldHistory.position = 10
        try database.saveHistory(oldHistory)

        let preferenceKey = "ios.test.backup.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: preferenceKey) }

        let site = Site(key: "restored", name: "Restored", api: "https://example.com/api", type: 1)
        let keep = Keep(key: "restored@@@2", vodName: "new")
        var history = History(key: "restored@@@2", vodName: "new")
        history.position = 42
        let document = BackupDocument(
            sites: [site],
            keeps: [keep],
            configs: [ConfigRecord(id: 0, type: 0, url: "https://example.com/config.json")],
            histories: [history],
            preferences: [preferenceKey: .string("restored")]
        )
        let validated = try BackupImportService().validate(document)

        try database.replaceAll(with: validated)

        XCTAssertEqual(try database.loadSites(), [site])
        XCTAssertEqual(try database.loadKeeps(), [keep])
        XCTAssertEqual(try database.loadHistories(limit: 100), [history])
        XCTAssertFalse(try database.containsKeep(key: oldKeep.key))
        XCTAssertEqual(UserDefaults.standard.string(forKey: preferenceKey), "restored")
    }

    func testAndroidPreferencesAreMappedToIOSPlaybackSettings() throws {
        let database = try AppDatabase.inMemory()
        let keys = [
            "ios.incognito", "ios.automaticLineChange", "ios.playerEngine", HTTPUserAgent.preferenceKey,
            "incognito", "change", "player_engine", "ua"
        ]
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
        let document = BackupDocument(
            configs: [ConfigRecord(type: 0, url: "https://example.com/config.json")],
            preferences: [
                "incognito": .bool(true),
                "change": .bool(false),
                "player_engine": .number(2),
                "ua": .string("Android-UA")
            ]
        )

        try database.replaceAll(with: BackupImportService().validate(document))

        XCTAssertEqual(UserDefaults.standard.object(forKey: "ios.incognito") as? Bool, true)
        XCTAssertEqual(UserDefaults.standard.object(forKey: "ios.automaticLineChange") as? Bool, false)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "ios.playerEngine"), PlayerEnginePreference.mpv.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: HTTPUserAgent.preferenceKey), "Android-UA")
    }

    func testAndroidIJKPreferenceMapsToMDK() throws {
        let database = try AppDatabase.inMemory()
        let keys = ["ios.playerEngine", "player_engine"]
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
        let document = BackupDocument(
            configs: [ConfigRecord(type: 0, url: "https://example.com/config.json")],
            preferences: ["player_engine": .number(1)]
        )

        try database.replaceAll(with: BackupImportService().validate(document))

        XCTAssertEqual(UserDefaults.standard.string(forKey: "ios.playerEngine"), PlayerEnginePreference.mdk.rawValue)
    }
}
