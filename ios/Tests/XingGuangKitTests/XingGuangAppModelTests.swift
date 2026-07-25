import XCTest
@testable import XingGuangKit

@MainActor
final class XingGuangAppModelTests: XCTestCase {
    func testValidConfigurationIsPersisted() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "https://example.com/vod.json"
        model.liveConfigURL = "file:///var/mobile/live.json"

        model.saveConfiguration()

        XCTAssertEqual(model.configurationSaveState, .saved)
        XCTAssertEqual(defaults.string(forKey: "ios.vodConfigURL"), "https://example.com/vod.json")
        XCTAssertEqual(defaults.string(forKey: "ios.liveConfigURL"), "file:///var/mobile/live.json")
    }

    func testInvalidConfigurationIsRejected() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "not a URL"

        model.saveConfiguration()

        XCTAssertEqual(model.configurationSaveState, .invalid)
        XCTAssertNil(defaults.string(forKey: "ios.vodConfigURL"))
    }

    func testCategorySelectionUpdatesPublishedState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        let category = model.categories[2]

        model.selectCategory(category)

        XCTAssertEqual(model.selectedCategory, category)
    }

    func testLatestSiteLoadWinsAfterRapidSwitch() async {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = Site(key: "first", name: "第一来源", api: "https://first.example", type: 1)
        let second = Site(key: "second", name: "第二来源", api: "https://second.example", type: 1)
        let repository = DelayedVodRepository()
        let model = XingGuangAppModel(selectedSite: first, defaults: defaults, repository: repository)

        model.selectSite(second)
        model.selectSite(first)
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let items) = model.catalogState else {
            return XCTFail("Expected the latest source catalog")
        }
        XCTAssertEqual(items.first?.vodName, "第一来源影片")
    }

    func testSelectedFiltersAreSentToCategoryRequest() async {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = FilterVodRepository()
        let category = VodClass(typeID: "movie", typeName: "电影")
        let model = XingGuangAppModel(
            selectedSite: Site(key: "api", name: "API", api: "https://example.com", type: 1),
            categories: [category],
            defaults: defaults,
            repository: repository
        )
        model.selectedFilters = ["year": "2026", "area": "CN"]

        model.applyFilters()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(repository.receivedFilters, ["year": "2026", "area": "CN"])
    }

    func testIncognitoSkipsPlaybackHistoryAndPreferencesPersist() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        let model = XingGuangAppModel(defaults: defaults, persistence: database)
        model.incognito = true
        model.automaticLineChange = false
        model.defaultPlaybackSpeed = 1.5

        let vod = Vod(vodID: "1", vodName: "影片")
        let route = PlaybackRoute(name: "线路", episodes: [PlaybackEpisode(name: "正片", url: "https://example.com/1.m3u8")])
        model.savePlayback(
            vod: vod,
            route: route,
            episode: route.episodes[0],
            time: PlayerTime(position: 30, duration: 120)
        )

        XCTAssertTrue(try database.loadHistories().isEmpty)
        XCTAssertEqual(defaults.object(forKey: "ios.incognito") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "ios.automaticLineChange") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "ios.defaultPlaybackSpeed") as? Double, 1.5)
    }

    func testBackupDocumentIncludesCurrentConfigurationAndAndroidAliases() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "https://example.com/vod.json"
        model.liveConfigURL = "https://example.com/live.json"
        model.playerPreference = .vlc
        model.incognito = true
        model.automaticLineChange = false

        let backup = try model.makeBackupDocument()

        XCTAssertEqual(Set(backup.configs.map(\.type)), Set([0, 1]))
        XCTAssertFalse(backup.sites.isEmpty)
        XCTAssertEqual(backup.preferences["player_engine"], .number(2))
        XCTAssertEqual(backup.preferences["incognito"], .bool(true))
        XCTAssertEqual(backup.preferences["change"], .bool(false))
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "XingGuangAppModelTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}

private final class FilterVodRepository: VodRepository, @unchecked Sendable {
    private(set) var receivedFilters: [String: String] = [:]

    func loadConfig(from url: URL) async throws -> VodConfigDocument { VodConfigDocument() }
    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult {
        receivedFilters = filters
        return VodResult()
    }
    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL)
    }
}

private final class DelayedVodRepository: VodRepository, @unchecked Sendable {
    func loadConfig(from url: URL) async throws -> VodConfigDocument { VodConfigDocument() }

    func home(site: Site, includeFilters: Bool) async throws -> VodResult {
        if site.key == "second" {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return VodResult(list: [Vod(vodID: site.key, vodName: "\(site.name)影片")])
    }

    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult {
        VodResult()
    }

    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL)
    }
}
