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

    func testCategoryPaginationAppendsUniqueItemsAndStopsAtLastPage() async {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = PagingVodRepository()
        let category = VodClass(typeID: "movie", typeName: "电影")
        let model = XingGuangAppModel(
            selectedSite: Site(key: "api", name: "API", api: "https://example.com", type: 1),
            categories: [category],
            defaults: defaults,
            repository: repository
        )

        model.selectCategory(category)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(model.catalogCanLoadMore)

        model.loadNextCategoryPage()
        try? await Task.sleep(nanoseconds: 100_000_000)

        guard case .loaded(let items) = model.catalogState else {
            return XCTFail("Expected paginated catalog")
        }
        XCTAssertEqual(items.map(\.vodID), ["1", "2"])
        XCTAssertEqual(repository.pages, [1, 2])
        XCTAssertFalse(model.catalogCanLoadMore)
    }

    func testSearchHistoryPersistsMostRecentTwentyWithoutCaseDuplicates() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)

        for index in 0..<22 { model.recordSearch("影片 \(index)") }
        model.recordSearch("影片 5")

        XCTAssertEqual(model.searchHistory.count, 20)
        XCTAssertEqual(model.searchHistory.first, "影片 5")
        XCTAssertEqual(model.searchHistory.filter { $0 == "影片 5" }.count, 1)
        XCTAssertEqual(defaults.stringArray(forKey: "ios.searchHistory"), model.searchHistory)

        model.clearSearchHistory()
        XCTAssertTrue(model.searchHistory.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: "ios.searchHistory"))
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

    func testPlaybackSavePreservesAndroidHistoryOptions() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        let model = XingGuangAppModel(defaults: defaults, persistence: database)
        let vod = Vod(vodID: "options", vodName: "影片")
        let episode = PlaybackEpisode(name: "第二集", url: "https://example.com/2.m3u8")
        let route = PlaybackRoute(name: "线路", episodes: [episode])

        model.savePlayback(
            vod: vod,
            route: route,
            episode: episode,
            time: PlayerTime(position: 30, duration: 120),
            speed: 1.5,
            reverseSort: true,
            opening: 12_000,
            ending: 8_000,
            scale: PlayerAspectMode.crop.rawValue
        )
        model.savePlayback(
            vod: vod,
            route: route,
            episode: episode,
            time: PlayerTime(position: 45, duration: 120),
            speed: 1.5
        )

        let history = try XCTUnwrap(database.loadHistories().first)
        XCTAssertTrue(history.reverseSort)
        XCTAssertEqual(history.opening, 12_000)
        XCTAssertEqual(history.ending, 8_000)
        XCTAssertEqual(history.scale, PlayerAspectMode.crop.rawValue)
        XCTAssertEqual(history.position, 45_000)
    }

    func testAspectPreferencesPersistAndExportAndroidAliases() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.defaultAspectMode = .standard
        model.liveAspectMode = .crop

        let backup = try model.makeBackupDocument()

        XCTAssertEqual(defaults.integer(forKey: "ios.playbackAspectMode"), PlayerAspectMode.standard.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "ios.liveAspectMode"), PlayerAspectMode.crop.rawValue)
        XCTAssertEqual(backup.preferences["scale"], .number(Double(PlayerAspectMode.standard.rawValue)))
        XCTAssertEqual(backup.preferences["scale_live"], .number(Double(PlayerAspectMode.crop.rawValue)))
    }

    func testBackupDocumentIncludesCurrentConfigurationAndAndroidAliases() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "https://example.com/vod.json"
        model.liveConfigURL = "https://example.com/live.json"
        model.playerPreference = .mpv
        model.incognito = true
        model.automaticLineChange = false

        let backup = try model.makeBackupDocument()

        XCTAssertEqual(Set(backup.configs.map(\.type)), Set([0, 1]))
        XCTAssertFalse(backup.sites.isEmpty)
        XCTAssertEqual(backup.preferences["player_engine"], .number(2))
        XCTAssertEqual(backup.preferences["incognito"], .bool(true))
        XCTAssertEqual(backup.preferences["change"], .bool(false))
    }

    func testRemovedIOSPlayerPreferencesFallBackToAVPlayer() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("vlc", forKey: "ios.playerEngine")

        let model = XingGuangAppModel(defaults: defaults)

        XCTAssertEqual(model.playerPreference, .avPlayer)
    }

    func testPlaybackRequiringSniffingIsResolvedBeforePlayerLoad() async throws {
        let repository = SniffingVodRepository()
        let sniffer = MockWebMediaSniffer()
        let model = XingGuangAppModel(
            selectedSite: Site(key: "sniff", name: "Sniff", api: "https://example.com", type: 3),
            repository: repository,
            webMediaSniffer: sniffer
        )
        let episode = PlaybackEpisode(name: "正片", url: "https://example.com/player")
        let route = PlaybackRoute(name: "线路", episodes: [episode])

        let request = try await model.resolvePlayback(route: route, episode: episode)

        XCTAssertEqual(request.url, "https://cdn.example/video.m3u8")
        XCTAssertFalse(request.requiresSniffing)
        XCTAssertEqual(sniffer.receivedSite?.key, "sniff")
    }

    func testLoadedConfigurationUpdatesSharedNetworkPolicy() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://example.com/config.json", forKey: "ios.vodConfigURL")
        let policy = HTTPNetworkPolicyStore()
        let repository = PolicyVodRepository()
        let model = XingGuangAppModel(
            defaults: defaults,
            repository: repository,
            networkPolicyStore: policy,
            usePreviewData: false
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 100_000_000)

        let prepared = try policy.prepare(HTTPRequest(url: URL(string: "https://api.example/catalog")!))
        XCTAssertEqual(prepared.headers["Referer"], "https://source.example/")
        XCTAssertThrowsError(try policy.prepare(HTTPRequest(url: URL(string: "https://ads.example/banner")!)))
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "XingGuangAppModelTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}

@MainActor
private final class MockWebMediaSniffer: WebMediaSniffing {
    private(set) var receivedSite: Site?

    func resolve(_ request: PlaybackRequest, site: Site) async throws -> PlaybackRequest {
        receivedSite = site
        var result = request
        result.url = "https://cdn.example/video.m3u8"
        result.requiresSniffing = false
        return result
    }
}

private final class SniffingVodRepository: VodRepository, @unchecked Sendable {
    func loadConfig(from url: URL) async throws -> VodConfigDocument { VodConfigDocument() }
    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult { VodResult() }
    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL, requiresSniffing: true)
    }
}

private final class PolicyVodRepository: VodRepository, @unchecked Sendable {
    private let site = Site(key: "policy", name: "Policy", api: "https://api.example", type: 1)

    func loadConfig(from url: URL) async throws -> VodConfigDocument {
        VodConfigDocument(
            sites: [site],
            ads: ["ads.example"],
            headers: [HTTPHeaderRule(host: "api.example", header: ["Referer": "https://source.example/"])]
        )
    }

    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult { VodResult() }
    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest { PlaybackRequest(url: episodeURL) }
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

private final class PagingVodRepository: VodRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storedPages: [Int] = []

    var pages: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storedPages
    }

    func loadConfig(from url: URL) async throws -> VodConfigDocument { VodConfigDocument() }
    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }

    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult {
        lock.lock()
        storedPages.append(page)
        lock.unlock()
        if page == 1 {
            return VodResult(list: [Vod(vodID: "1", vodName: "第一页")], pageCount: 2)
        }
        return VodResult(
            list: [Vod(vodID: "1", vodName: "重复"), Vod(vodID: "2", vodName: "第二页")],
            pageCount: 2
        )
    }

    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL)
    }
}
