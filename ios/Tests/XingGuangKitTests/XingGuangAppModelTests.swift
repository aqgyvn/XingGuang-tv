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

    func testConfigurationHistoryProtectsCurrentRecordAndDeletesInactiveRecord() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        try database.saveConfigurationRecord(ConfigRecord(type: 0, time: 20, url: "https://example.com/current.json", name: "当前"))
        try database.saveConfigurationRecord(ConfigRecord(type: 0, time: 10, url: "https://example.com/old.json", name: "旧配置"))
        defaults.set("https://example.com/current.json", forKey: "ios.vodConfigURL")
        let model = XingGuangAppModel(defaults: defaults, persistence: database, usePreviewData: false)

        model.bootstrap()

        let current = try XCTUnwrap(model.configurationHistory.first(where: { $0.url.contains("current") }))
        let inactive = try XCTUnwrap(model.configurationHistory.first(where: { $0.url.contains("old") }))
        XCTAssertTrue(model.isCurrentConfiguration(current))
        XCTAssertFalse(model.deleteConfiguration(current))
        XCTAssertTrue(model.deleteConfiguration(inactive))
        XCTAssertEqual(model.configurationHistory.map(\.url), ["https://example.com/current.json"])
    }

    func testActivatingVodConfigurationReloadsAndPersistsSelection() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        let record = ConfigRecord(type: 0, time: 10, url: "https://example.com/selected.json", name: "点播")
        try database.saveConfigurationRecord(record)
        let repository = ConfigurationHistoryVodRepository()
        let model = XingGuangAppModel(
            defaults: defaults,
            repository: repository,
            persistence: database,
            usePreviewData: false
        )

        model.activateConfiguration(record)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(model.vodConfigURL, record.url)
        XCTAssertEqual(defaults.string(forKey: "ios.vodConfigURL"), record.url)
        XCTAssertEqual(model.selectedSite.key, "history")
        XCTAssertEqual(model.configurationSaveState, .saved)
        XCTAssertTrue(model.configurationHistory.contains(where: { $0.type == 0 && $0.url == record.url }))
    }

    func testLoadedLiveConfigurationIsAddedToHistory() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        let model = XingGuangAppModel(
            defaults: defaults,
            liveRepository: ConfigurationHistoryLiveRepository(),
            persistence: database,
            usePreviewData: false
        )
        model.liveConfigURL = "https://example.com/live.txt"

        model.saveConfiguration()
        try await Task.sleep(nanoseconds: 100_000_000)

        let record = try XCTUnwrap(model.configurationHistory.first)
        XCTAssertEqual(record.type, 1)
        XCTAssertEqual(record.url, "https://example.com/live.txt")
        XCTAssertEqual(record.name, "历史直播")
        XCTAssertEqual(model.configurationSaveState, .saved)
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

    func testAggregateSearchLimitsConcurrencyKeepsSourceOrderAndIsolatesFailures() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://example.com/config.json", forKey: "ios.vodConfigURL")
        let repository = AggregateSearchVodRepository()
        let model = XingGuangAppModel(
            defaults: defaults,
            repository: repository,
            usePreviewData: false
        )
        model.bootstrap()
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await model.searchAllSites(keyword: "星光", maximumConcurrentRequests: 2)

        XCTAssertLessThanOrEqual(repository.maximumActiveRequests, 2)
        XCTAssertEqual(result.items.map(\.id), ["first@@@same", "second@@@same", "third@@@third"])
        XCTAssertEqual(result.failedSiteNames, ["失败站点"])
        XCTAssertTrue(result.canLoadMore)
    }

    func testAggregateSearchCancellationPropagates() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("https://example.com/config.json", forKey: "ios.vodConfigURL")
        let repository = AggregateSearchVodRepository(delayNanoseconds: 200_000_000)
        let model = XingGuangAppModel(defaults: defaults, repository: repository, usePreviewData: false)
        model.bootstrap()
        try await Task.sleep(nanoseconds: 20_000_000)

        let task = Task { try await model.searchAllSites(keyword: "取消", maximumConcurrentRequests: 2) }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        }
    }

    func testSearchResultSourceIsUsedForKeepAndHistoryKeys() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        let first = Site(key: "first", name: "第一站")
        let second = Site(key: "second", name: "第二站")
        let model = XingGuangAppModel(selectedSite: first, defaults: defaults, persistence: database)
        let vod = Vod(vodID: "same", vodName: "同名影片")
        let route = PlaybackRoute(name: "线路", episodes: [PlaybackEpisode(name: "正片", url: "https://example.com/video.m3u8")])

        XCTAssertTrue(model.toggleKeep(vod: vod, site: second))
        model.savePlayback(vod: vod, route: route, episode: route.episodes[0], time: PlayerTime(position: 10, duration: 100), site: second)

        XCTAssertTrue(model.isKept(vod, site: second))
        XCTAssertFalse(model.isKept(vod, site: first))
        XCTAssertNotNil(model.history(for: vod, site: second))
        XCTAssertNil(model.history(for: vod, site: first))
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
        model.globalUserAgent = "XingGuang-UA"

        let backup = try model.makeBackupDocument()

        XCTAssertEqual(Set(backup.configs.map(\.type)), Set([0, 1]))
        XCTAssertFalse(backup.sites.isEmpty)
        XCTAssertEqual(backup.preferences["player_engine"], .number(2))
        XCTAssertEqual(backup.preferences["incognito"], .bool(true))
        XCTAssertEqual(backup.preferences["change"], .bool(false))
        XCTAssertEqual(backup.preferences["ua"], .string("XingGuang-UA"))
        XCTAssertEqual(backup.preferences[HTTPUserAgent.preferenceKey], .string("XingGuang-UA"))
    }

    func testBackupDocumentIncludesAllStoredConfigurationHistory() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let database = try AppDatabase.inMemory()
        try database.saveConfigurationRecord(ConfigRecord(type: 0, time: 20, url: "https://example.com/new.json"))
        try database.saveConfigurationRecord(ConfigRecord(type: 0, time: 10, url: "https://example.com/old.json"))
        try database.saveConfigurationRecord(ConfigRecord(type: 1, time: 15, url: "https://example.com/live.txt"))
        let model = XingGuangAppModel(defaults: defaults, persistence: database, usePreviewData: false)

        let backup = try model.makeBackupDocument()

        XCTAssertEqual(Set(backup.configs.map(\.url)), Set([
            "https://example.com/new.json",
            "https://example.com/old.json",
            "https://example.com/live.txt"
        ]))
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
        model.globalUserAgent = "Global-UA"

        let request = try await model.resolvePlayback(route: route, episode: episode)

        XCTAssertEqual(request.url, "https://cdn.example/video.m3u8")
        XCTAssertFalse(request.requiresSniffing)
        XCTAssertEqual(sniffer.receivedSite?.key, "sniff")
        XCTAssertEqual(sniffer.receivedRequest?.headers["User-Agent"], "Global-UA")
    }

    func testLivePlaybackUsesGlobalUserAgentOnlyAsFallback() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.globalUserAgent = "Global-UA"
        let live = Live(name: "直播")
        var channel = Channel(name: "频道", urls: ["https://example.com/live.m3u8"])

        let fallback = try model.livePlaybackRequest(live: live, channel: channel)
        XCTAssertEqual(fallback.headers["User-Agent"], "Global-UA")

        channel.userAgent = "Channel-UA"
        let explicit = try model.livePlaybackRequest(live: live, channel: channel)
        XCTAssertEqual(explicit.headers["User-Agent"], "Channel-UA")
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
    private(set) var receivedRequest: PlaybackRequest?

    func resolve(_ request: PlaybackRequest, site: Site) async throws -> PlaybackRequest {
        receivedSite = site
        receivedRequest = request
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

private final class ConfigurationHistoryVodRepository: VodRepository, @unchecked Sendable {
    func loadConfig(from url: URL) async throws -> VodConfigDocument {
        VodConfigDocument(sites: [Site(key: "history", name: "历史站点", api: "https://api.example", type: 1)])
    }

    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult { VodResult() }
    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL)
    }
}

private final class ConfigurationHistoryLiveRepository: LiveRepository {
    func load(_ live: Live) async throws -> Live {
        Live(
            name: "历史直播",
            url: live.url,
            groups: [LiveGroup(name: "默认", channels: [Channel(name: "频道", urls: ["https://example.com/live.m3u8"])])]
        )
    }

    func loadEPG(for live: Live, channel: Channel?) async throws -> [Epg] { [] }
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

private final class AggregateSearchVodRepository: VodRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let delayNanoseconds: UInt64
    private var activeRequests = 0
    private var storedMaximumActiveRequests = 0

    init(delayNanoseconds: UInt64 = 30_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    var maximumActiveRequests: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedMaximumActiveRequests
    }

    func loadConfig(from url: URL) async throws -> VodConfigDocument {
        VodConfigDocument(sites: [
            Site(key: "first", name: "第一站", api: "https://first.example", type: 1),
            Site(key: "failure", name: "失败站点", api: "https://failure.example", type: 1),
            Site(key: "second", name: "第二站", api: "https://second.example", type: 1),
            Site(key: "third", name: "第三站", api: "https://third.example", type: 1)
        ])
    }

    func home(site: Site, includeFilters: Bool) async throws -> VodResult { VodResult() }
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult { VodResult() }

    func search(site: Site, keyword: String, page: Int) async throws -> VodResult {
        lock.lock()
        activeRequests += 1
        storedMaximumActiveRequests = max(storedMaximumActiveRequests, activeRequests)
        lock.unlock()
        defer {
            lock.lock()
            activeRequests -= 1
            lock.unlock()
        }
        try await Task.sleep(nanoseconds: delayNanoseconds)
        if site.key == "failure" { throw URLError(.cannotConnectToHost) }
        let vodID = site.key == "third" ? "third" : "same"
        let vod = Vod(vodID: vodID, vodName: "\(site.name)影片")
        return VodResult(list: site.key == "first" ? [vod, vod] : [vod], pageCount: site.key == "first" ? 2 : 1)
    }

    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest { PlaybackRequest(url: episodeURL) }
}
