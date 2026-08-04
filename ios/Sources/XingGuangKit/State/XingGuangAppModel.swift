import Combine
import Foundation

public enum CatalogState: Equatable {
    case loading
    case loaded([Vod])
    case empty
    case failed(String)
}

public enum ConfigurationSaveState: Equatable {
    case idle
    case loading
    case saved
    case invalid
    case failed(String)
}

public enum LiveLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

public enum CatalogDisplaySize: Int, Codable, CaseIterable, Identifiable {
    case compact
    case standard
    case spacious
    case extraLarge

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .compact: return "小"
        case .standard: return "中"
        case .spacious: return "大"
        case .extraLarge: return "特大"
        }
    }

    public var posterMinimumWidth: Double {
        switch self {
        case .compact: return 96
        case .standard: return 128
        case .spacious: return 160
        case .extraLarge: return 192
        }
    }
}

@MainActor
public final class XingGuangAppModel: ObservableObject {
    @Published public var selectedSite: Site
    @Published public var selectedCategory: VodClass
    @Published public private(set) var categories: [VodClass]
    @Published public private(set) var filters: [String: [VodFilter]]
    @Published public var selectedFilters: [String: String]
    @Published public private(set) var catalogState: CatalogState
    @Published public private(set) var catalogLoadingMore = false
    @Published public private(set) var catalogCanLoadMore = false
    @Published public private(set) var searchHistory: [String]
    @Published public var vodConfigURL: String
    @Published public var liveConfigURL: String
    @Published public private(set) var configurationSaveState: ConfigurationSaveState = .idle
    @Published public private(set) var liveSources: [Live]
    @Published public private(set) var liveState: LiveLoadState
    @Published public var selectedLiveSourceName: String {
        didSet { defaults.set(selectedLiveSourceName, forKey: "ios.selectedLiveSourceName") }
    }
    public private(set) var selectedLiveSourceURL: String {
        didSet { defaults.set(selectedLiveSourceURL, forKey: "ios.selectedLiveSourceURL") }
    }
    @Published public private(set) var keeps: [Keep]
    @Published public private(set) var histories: [History]
    @Published public private(set) var configurationHistory: [ConfigRecord]
    @Published public private(set) var configurationHistoryError = ""
    @Published public var incognito: Bool {
        didSet { defaults.set(incognito, forKey: "ios.incognito") }
    }
    @Published public var automaticLineChange: Bool {
        didSet { defaults.set(automaticLineChange, forKey: "ios.automaticLineChange") }
    }
    @Published public var defaultPlaybackSpeed: Double {
        didSet { defaults.set(defaultPlaybackSpeed, forKey: "ios.defaultPlaybackSpeed") }
    }
    @Published public var longPressPlaybackSpeed: Double {
        didSet {
            let value = min(max(longPressPlaybackSpeed, 2), 5)
            if value != longPressPlaybackSpeed {
                longPressPlaybackSpeed = value
            }
            defaults.set(value, forKey: "ios.longPressPlaybackSpeed")
        }
    }
    @Published public var defaultAspectMode: PlayerAspectMode {
        didSet { defaults.set(defaultAspectMode.rawValue, forKey: "ios.playbackAspectMode") }
    }
    @Published public var liveAspectMode: PlayerAspectMode {
        didSet { defaults.set(liveAspectMode.rawValue, forKey: "ios.liveAspectMode") }
    }
    @Published public var playerPreference: PlayerEnginePreference {
        didSet { defaults.set(playerPreference.rawValue, forKey: "ios.playerEngine") }
    }
    @Published public var subtitleTextSize: Double {
        didSet { defaults.set(subtitleTextSize, forKey: "ios.subtitleTextSize") }
    }
    @Published public var subtitleBottomOffset: Double {
        didSet { defaults.set(subtitleBottomOffset, forKey: "ios.subtitleBottomOffset") }
    }
    @Published public var danmakuEnabled: Bool {
        didSet { defaults.set(danmakuEnabled, forKey: "ios.danmakuEnabled") }
    }
    @Published public var danmakuLoadEnabled: Bool {
        didSet { defaults.set(danmakuLoadEnabled, forKey: "ios.danmakuLoadEnabled") }
    }
    @Published public var globalUserAgent: String {
        didSet { defaults.set(globalUserAgent, forKey: HTTPUserAgent.preferenceKey) }
    }
    @Published public var catalogDisplaySize: CatalogDisplaySize {
        didSet { defaults.set(catalogDisplaySize.rawValue, forKey: "ios.catalogDisplaySize") }
    }
    @Published public var adHostBlockingEnabled: Bool {
        didSet {
            defaults.set(adHostBlockingEnabled, forKey: "ios.adHostBlockingEnabled")
            networkPolicyStore?.setAdHostBlockingEnabled(adHostBlockingEnabled)
        }
    }

    public var continueWatching: History? { histories.first }
    public var repositoryAvailable: Bool { repository != nil }
    public var activeFilters: [VodFilter] { filters[selectedCategory.typeID] ?? [] }
    public private(set) var configuration: VodConfigDocument

    private let repository: VodRepository?
    private let liveRepository: LiveRepository?
    private let persistence: PersistenceStore?
    private let playerFactory: PlayerEngineFactory
    private let timedTextLoader: any TimedTextLoading
    private let webMediaSniffer: (any WebMediaSniffing)?
    private let networkPolicyStore: HTTPNetworkPolicyStore?
    private let defaults: UserDefaults
    private var selectedVodSiteKey: String {
        didSet { defaults.set(selectedVodSiteKey, forKey: "ios.selectedVodSiteKey") }
    }
    private var configurationTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var catalogPage = 1
    private var catalogPageCount = 1

    public init(
        selectedSite: Site = PreviewFixtures.site,
        categories: [VodClass] = PreviewFixtures.categories,
        catalogState: CatalogState = .loaded(PreviewFixtures.vods),
        liveSources: [Live] = PreviewFixtures.config.lives,
        continueWatching: History? = PreviewFixtures.history,
        keeps: [Keep] = PreviewFixtures.keeps,
        defaults: UserDefaults = .standard,
        repository: VodRepository? = nil,
        liveRepository: LiveRepository? = nil,
        persistence: PersistenceStore? = nil,
        playerFactory: PlayerEngineFactory = PreviewPlayerEngineFactory(),
        timedTextLoader: any TimedTextLoading = TimedTextLoader(),
        webMediaSniffer: (any WebMediaSniffing)? = nil,
        networkPolicyStore: HTTPNetworkPolicyStore? = nil,
        usePreviewData: Bool = true
    ) {
        self.repository = repository
        self.liveRepository = liveRepository
        self.persistence = persistence
        self.playerFactory = playerFactory
        self.timedTextLoader = timedTextLoader
        self.webMediaSniffer = webMediaSniffer
        self.networkPolicyStore = networkPolicyStore
        self.defaults = defaults
        self.vodConfigURL = defaults.string(forKey: "ios.vodConfigURL") ?? ""
        self.liveConfigURL = defaults.string(forKey: "ios.liveConfigURL") ?? ""
        self.selectedVodSiteKey = defaults.string(forKey: "ios.selectedVodSiteKey") ?? ""
        self.selectedLiveSourceName = defaults.string(forKey: "ios.selectedLiveSourceName") ?? ""
        self.selectedLiveSourceURL = defaults.string(forKey: "ios.selectedLiveSourceURL") ?? ""
        self.incognito = defaults.object(forKey: "ios.incognito") as? Bool ?? false
        self.automaticLineChange = defaults.object(forKey: "ios.automaticLineChange") as? Bool ?? true
        let storedSpeed = defaults.object(forKey: "ios.defaultPlaybackSpeed") as? Double ?? 1
        self.defaultPlaybackSpeed = min(max(storedSpeed, 0.5), 2)
        let storedLongPressSpeed = defaults.object(forKey: "ios.longPressPlaybackSpeed") as? Double
            ?? defaults.object(forKey: "speed") as? Double
            ?? 3
        self.longPressPlaybackSpeed = min(max(storedLongPressSpeed, 2), 5)
        let storedAspect = defaults.object(forKey: "ios.playbackAspectMode") as? Int ?? 0
        let defaultAspectMode = PlayerAspectMode(rawValue: storedAspect) ?? .original
        self.defaultAspectMode = defaultAspectMode
        let storedLiveAspect = defaults.object(forKey: "ios.liveAspectMode") as? Int ?? storedAspect
        self.liveAspectMode = PlayerAspectMode(rawValue: storedLiveAspect) ?? defaultAspectMode
        let storedPlayerPreference = defaults.string(forKey: "ios.playerEngine") ?? ""
        self.playerPreference = PlayerEnginePreference(rawValue: storedPlayerPreference) ?? .avPlayer
        if !storedPlayerPreference.isEmpty, PlayerEnginePreference(rawValue: storedPlayerPreference) == nil {
            defaults.set(PlayerEnginePreference.avPlayer.rawValue, forKey: "ios.playerEngine")
        }
        let storedSubtitleSize = defaults.object(forKey: "ios.subtitleTextSize") as? Double ?? 22
        self.subtitleTextSize = min(max(storedSubtitleSize, 14), 42)
        let storedSubtitleOffset = defaults.object(forKey: "ios.subtitleBottomOffset") as? Double ?? 24
        self.subtitleBottomOffset = min(max(storedSubtitleOffset, 8), 120)
        self.danmakuEnabled = defaults.object(forKey: "ios.danmakuEnabled") as? Bool ?? true
        self.danmakuLoadEnabled = defaults.object(forKey: "ios.danmakuLoadEnabled") as? Bool
            ?? defaults.object(forKey: "danmaku_load") as? Bool
            ?? true
        self.globalUserAgent = HTTPUserAgent.configured(defaults: defaults)
        self.catalogDisplaySize = CatalogDisplaySize(
            rawValue: defaults.object(forKey: "ios.catalogDisplaySize") as? Int ?? CatalogDisplaySize.standard.rawValue
        ) ?? .standard
        self.adHostBlockingEnabled = defaults.object(forKey: "ios.adHostBlockingEnabled") as? Bool
            ?? defaults.object(forKey: "ad_host_block") as? Bool
            ?? true
        self.searchHistory = Array((defaults.stringArray(forKey: "ios.searchHistory") ?? []).prefix(20))

        if usePreviewData {
            self.configuration = PreviewFixtures.config
            self.selectedSite = selectedSite
            self.categories = categories
            self.filters = [:]
            self.selectedFilters = [:]
            self.selectedCategory = categories.first ?? VodClass(typeID: "all", typeName: "全部")
            self.catalogState = catalogState
            self.liveSources = liveSources
            self.liveState = liveSources.isEmpty ? .empty : .loaded
            self.keeps = keeps
            self.histories = continueWatching.map { [$0] } ?? []
            self.configurationHistory = []
        } else {
            let emptyCategory = VodClass(typeID: "", typeName: "")
            self.configuration = VodConfigDocument()
            self.selectedSite = Site()
            self.categories = []
            self.filters = [:]
            self.selectedFilters = [:]
            self.selectedCategory = emptyCategory
            self.catalogState = .empty
            self.liveSources = []
            self.liveState = .idle
            self.keeps = []
            self.histories = []
            self.configurationHistory = []
        }
        networkPolicyStore?.setAdHostBlockingEnabled(adHostBlockingEnabled)
    }

    public func bootstrap() {
        reloadPersistence()
        if !vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadConfiguration()
        } else if !liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadLiveConfiguration()
        } else if !liveSources.isEmpty {
            loadLiveSources(liveSources)
        }
    }

    public func selectCategory(_ category: VodClass) {
        selectedCategory = category
        selectedFilters = defaultFilterValues(filters[category.typeID] ?? [])
        loadCategory(category)
    }

    /// Applies the currently selected Android-compatible filter values to the
    /// active category request.
    public func applyFilters() {
        loadCategory(selectedCategory)
    }

    public func loadNextCategoryPage() {
        guard let repository,
              !catalogLoadingMore,
              catalogCanLoadMore,
              case .loaded(let currentItems) = catalogState else { return }
        let site = selectedSite
        let category = selectedCategory
        let filters = selectedFilters
        let nextPage = catalogPage + 1
        catalogLoadingMore = true
        catalogTask = Task { [weak self] in
            guard let self else { return }
            defer { catalogLoadingMore = false }
            do {
                let result = try await repository.category(
                    site: site,
                    typeID: category.typeID,
                    page: nextPage,
                    filters: filters
                )
                try Task.checkCancellation()
                guard selectedSite.key == site.key,
                      selectedCategory.typeID == category.typeID,
                      selectedFilters == filters else { return }
                var identifiers = Set(currentItems.map(\.id))
                let appended = result.list.filter { identifiers.insert($0.id).inserted }
                catalogPage = nextPage
                catalogPageCount = max(result.pageCount, nextPage)
                catalogCanLoadMore = nextPage < catalogPageCount
                catalogState = .loaded(currentItems + appended)
            } catch is CancellationError {
            } catch {
            }
        }
    }

    public func selectSite(_ site: Site) {
        guard !site.key.isEmpty, site.changeable == 1 else { return }
        guard selectedSite.key != site.key else {
            selectedVodSiteKey = site.key
            return
        }
        selectedSite = site
        selectedVodSiteKey = site.key
        loadHome()
    }

    public func selectLiveSource(_ source: Live) {
        guard !source.name.isEmpty || !source.url.isEmpty else { return }
        selectedLiveSourceName = source.name
        selectedLiveSourceURL = source.url
    }

    public func saveConfiguration() {
        guard isValidOptionalURL(vodConfigURL), isValidOptionalURL(liveConfigURL) else {
            configurationSaveState = .invalid
            return
        }
        vodConfigURL = vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        liveConfigURL = liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(vodConfigURL, forKey: "ios.vodConfigURL")
        defaults.set(liveConfigURL, forKey: "ios.liveConfigURL")
        if repository != nil, !vodConfigURL.isEmpty {
            loadConfiguration()
        } else if liveRepository != nil, !liveConfigURL.isEmpty {
            configurationSaveState = .loading
            loadLiveConfiguration(updateConfigurationState: true)
        } else {
            configurationSaveState = .saved
        }
    }

    public func saveConfiguration(_ kind: ConfigurationKind) {
        switch kind {
        case .vod:
            guard isValidOptionalURL(vodConfigURL) else {
                configurationSaveState = .invalid
                return
            }
            vodConfigURL = vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(vodConfigURL, forKey: "ios.vodConfigURL")
            if repository != nil, !vodConfigURL.isEmpty {
                loadConfiguration(loadConfiguredLiveSource: false)
            } else {
                configurationSaveState = .saved
            }
        case .live:
            guard isValidOptionalURL(liveConfigURL) else {
                configurationSaveState = .invalid
                return
            }
            liveConfigURL = liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(liveConfigURL, forKey: "ios.liveConfigURL")
            if liveRepository != nil, !liveConfigURL.isEmpty {
                configurationSaveState = .loading
                loadLiveConfiguration(updateConfigurationState: true)
            } else {
                configurationSaveState = .saved
            }
        }
    }

    public func resetConfigurationSaveState() {
        configurationSaveState = .idle
    }

    public func isCurrentConfiguration(_ record: ConfigRecord) -> Bool {
        let current = record.type == 0 ? vodConfigURL : liveConfigURL
        return current.trimmingCharacters(in: .whitespacesAndNewlines)
            == record.url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func activateConfiguration(_ record: ConfigRecord) {
        let url = record.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard record.type == 0 || record.type == 1, !url.isEmpty else { return }
        guard isValidOptionalURL(url) else {
            configurationSaveState = .invalid
            return
        }
        guard !isCurrentConfiguration(record) else { return }
        configurationHistoryError = ""
        configurationSaveState = .loading
        if record.type == 0 {
            vodConfigURL = url
            defaults.set(url, forKey: "ios.vodConfigURL")
            loadConfiguration()
        } else {
            liveConfigURL = url
            defaults.set(url, forKey: "ios.liveConfigURL")
            loadLiveConfiguration(updateConfigurationState: true)
        }
    }

    @discardableResult
    public func deleteConfiguration(_ record: ConfigRecord) -> Bool {
        guard !isCurrentConfiguration(record) else { return false }
        guard let persistence else {
            configurationHistoryError = "配置历史存储不可用"
            return false
        }
        do {
            try persistence.deleteConfiguration(id: record.id)
            configurationHistoryError = ""
            reloadPersistence()
            return true
        } catch {
            configurationHistoryError = error.localizedDescription
            return false
        }
    }

    public func reloadPreferences() {
        incognito = defaults.object(forKey: "ios.incognito") as? Bool ?? incognito
        automaticLineChange = defaults.object(forKey: "ios.automaticLineChange") as? Bool ?? automaticLineChange
        defaultPlaybackSpeed = min(max(defaults.object(forKey: "ios.defaultPlaybackSpeed") as? Double ?? defaultPlaybackSpeed, 0.5), 2)
        longPressPlaybackSpeed = min(max(
            defaults.object(forKey: "ios.longPressPlaybackSpeed") as? Double
                ?? defaults.object(forKey: "speed") as? Double
                ?? longPressPlaybackSpeed,
            2
        ), 5)
        defaultAspectMode = PlayerAspectMode(rawValue: defaults.object(forKey: "ios.playbackAspectMode") as? Int ?? defaultAspectMode.rawValue) ?? defaultAspectMode
        liveAspectMode = PlayerAspectMode(rawValue: defaults.object(forKey: "ios.liveAspectMode") as? Int ?? liveAspectMode.rawValue) ?? liveAspectMode
        playerPreference = PlayerEnginePreference(rawValue: defaults.string(forKey: "ios.playerEngine") ?? "") ?? playerPreference
        subtitleTextSize = min(max(defaults.object(forKey: "ios.subtitleTextSize") as? Double ?? subtitleTextSize, 14), 42)
        subtitleBottomOffset = min(max(defaults.object(forKey: "ios.subtitleBottomOffset") as? Double ?? subtitleBottomOffset, 8), 120)
        danmakuEnabled = defaults.object(forKey: "ios.danmakuEnabled") as? Bool ?? danmakuEnabled
        danmakuLoadEnabled = defaults.object(forKey: "ios.danmakuLoadEnabled") as? Bool
            ?? defaults.object(forKey: "danmaku_load") as? Bool
            ?? danmakuLoadEnabled
        globalUserAgent = HTTPUserAgent.configured(defaults: defaults)
        catalogDisplaySize = CatalogDisplaySize(
            rawValue: defaults.object(forKey: "ios.catalogDisplaySize") as? Int ?? catalogDisplaySize.rawValue
        ) ?? catalogDisplaySize
        adHostBlockingEnabled = defaults.object(forKey: "ios.adHostBlockingEnabled") as? Bool
            ?? defaults.object(forKey: "ad_host_block") as? Bool
            ?? adHostBlockingEnabled
        selectedVodSiteKey = defaults.string(forKey: "ios.selectedVodSiteKey") ?? selectedVodSiteKey
        selectedLiveSourceName = defaults.string(forKey: "ios.selectedLiveSourceName") ?? selectedLiveSourceName
        selectedLiveSourceURL = defaults.string(forKey: "ios.selectedLiveSourceURL") ?? selectedLiveSourceURL
    }

    public func search(keyword: String, page: Int = 1) async throws -> [Vod] {
        try await searchPage(keyword: keyword, page: page).list
    }

    public func searchPage(keyword: String, page: Int = 1, site: Site? = nil) async throws -> VodResult {
        let sourceSite = site ?? selectedSite
        guard let repository, !sourceSite.key.isEmpty else { return VodResult() }
        return try await repository.search(site: sourceSite, keyword: keyword, page: page)
    }

    public func searchAllSites(keyword: String, page: Int = 1, maximumConcurrentRequests: Int = 4) async throws -> AggregateVodSearchPage {
        guard let repository else { return AggregateVodSearchPage() }
        let sites = configuration.sites.filter { $0.hide != 1 && $0.searchable != 0 && !$0.key.isEmpty }
        guard !sites.isEmpty else { return AggregateVodSearchPage() }
        let concurrency = max(1, min(maximumConcurrentRequests, sites.count))

        let outcomes = try await withThrowingTaskGroup(of: AggregateSearchOutcome.self) { group in
            var nextIndex = 0
            var collected: [AggregateSearchOutcome] = []

            func addNext() {
                guard nextIndex < sites.count else { return }
                let index = nextIndex
                let site = sites[index]
                nextIndex += 1
                group.addTask {
                    do {
                        let result = try await repository.search(site: site, keyword: keyword, page: page)
                        try Task.checkCancellation()
                        return AggregateSearchOutcome(index: index, site: site, result: result, errorMessage: nil)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return AggregateSearchOutcome(index: index, site: site, result: nil, errorMessage: error.localizedDescription)
                    }
                }
            }

            for _ in 0..<concurrency { addNext() }
            while let outcome = try await group.next() {
                collected.append(outcome)
                addNext()
            }
            return collected.sorted { $0.index < $1.index }
        }

        try Task.checkCancellation()
        let succeeded = outcomes.compactMap { outcome -> (Site, VodResult)? in
            guard let result = outcome.result else { return nil }
            return (outcome.site, result)
        }
        let failures = outcomes.compactMap { $0.errorMessage == nil ? nil : $0.site.name }
        if succeeded.isEmpty, !failures.isEmpty {
            throw AggregateVodSearchError.allSitesFailed(failures)
        }

        var identifiers = Set<String>()
        var items: [VodSearchItem] = []
        for (site, result) in succeeded {
            for vod in result.list {
                let item = VodSearchItem(site: site, vod: vod)
                if identifiers.insert(item.id).inserted { items.append(item) }
            }
        }
        return AggregateVodSearchPage(
            items: items,
            canLoadMore: succeeded.contains { page < max($0.1.pageCount, 1) },
            failedSiteNames: failures
        )
    }

    public func recordSearch(_ keyword: String) {
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        searchHistory.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        searchHistory.insert(value, at: 0)
        if searchHistory.count > 20 { searchHistory.removeLast(searchHistory.count - 20) }
        defaults.set(searchHistory, forKey: "ios.searchHistory")
    }

    public func removeSearchHistory(_ keyword: String) {
        searchHistory.removeAll { $0 == keyword }
        defaults.set(searchHistory, forKey: "ios.searchHistory")
    }

    public func clearSearchHistory() {
        searchHistory = []
        defaults.removeObject(forKey: "ios.searchHistory")
    }

    public func detail(for vod: Vod, site: Site? = nil) async throws -> Vod {
        let sourceSite = site ?? selectedSite
        guard let repository, !sourceSite.key.isEmpty else { return vod }
        return try await repository.detail(site: sourceSite, vodID: vod.vodID).list.first ?? vod
    }

    public func resolvePlayback(site: Site? = nil, route: PlaybackRoute, episode: PlaybackEpisode) async throws -> PlaybackRequest {
        let sourceSite = site ?? selectedSite
        guard let repository else {
            var request = PlaybackRequest(url: episode.url)
            request.headers = HTTPUserAgent.applyingDefault(to: request.headers, value: globalUserAgent)
            request.enginePreference = playerPreference
            return request
        }
        let context = VodPlaybackContext(parses: configuration.parses, flags: configuration.flags)
        var request = try await repository.resolvePlayback(context: context, site: sourceSite, flag: route.name, episodeURL: episode.url)
        request.headers = HTTPUserAgent.applyingDefault(to: request.headers, value: globalUserAgent)
        if request.requiresSniffing {
            guard let webMediaSniffer else {
                throw VodRepositoryError.unsupportedPlayback("当前运行环境未配置网页媒体嗅探器")
            }
            request = try await webMediaSniffer.resolve(request, site: sourceSite)
        }
        request.enginePreference = playerPreference
        return request
    }

    public func makePlayerSession() -> PlayerSession {
        PlayerSession(engine: playerFactory.makePlayer(preference: playerPreference))
    }

    public func loadSubtitle(_ resource: SubtitleResource, request: PlaybackRequest) async throws -> [TimedTextCue] {
        try await timedTextLoader.loadSubtitle(resource, headers: request.headers, cookies: request.cookies)
    }

    public func loadDanmaku(_ resource: DanmakuResource, request: PlaybackRequest) async throws -> [DanmakuCue] {
        try await timedTextLoader.loadDanmaku(resource, headers: request.headers, cookies: request.cookies)
    }

    public func makeBackupDocument() throws -> BackupDocument {
        let encoder = JSONEncoder()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var configs = (try persistence?.loadConfigurations()) ?? []
        let currentVodSiteKey = selectedVodSiteKey.isEmpty ? selectedSite.key : selectedVodSiteKey
        let vodURL = vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vodURL.isEmpty {
            let data = try encoder.encode(configuration)
            let current = ConfigRecord(
                type: 0,
                time: now,
                url: vodURL,
                json: String(data: data, encoding: .utf8) ?? "",
                name: "点播",
                logo: configuration.logo,
                home: currentVodSiteKey
            )
            if !configs.contains(where: { $0.type == 0 && $0.url == vodURL }) { configs.append(current) }
        }
        let liveURL = liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveURL.isEmpty {
            let data = try encoder.encode(liveSources)
            let current = ConfigRecord(
                type: 1,
                time: now,
                url: liveURL,
                json: String(data: data, encoding: .utf8) ?? "",
                name: "直播"
            )
            if !configs.contains(where: { $0.type == 1 && $0.url == liveURL }) { configs.append(current) }
        }
        return BackupDocument(
            sites: configuration.sites,
            lives: liveSources,
            keeps: keeps,
            configs: configs,
            histories: histories,
            preferences: [
                "ios.playerEngine": .string(playerPreference.rawValue),
                "ios.incognito": .bool(incognito),
                "ios.automaticLineChange": .bool(automaticLineChange),
                "ios.defaultPlaybackSpeed": .number(defaultPlaybackSpeed),
                "ios.longPressPlaybackSpeed": .number(longPressPlaybackSpeed),
                "ios.playbackAspectMode": .number(Double(defaultAspectMode.rawValue)),
                "ios.liveAspectMode": .number(Double(liveAspectMode.rawValue)),
                "ios.subtitleTextSize": .number(subtitleTextSize),
                "ios.subtitleBottomOffset": .number(subtitleBottomOffset),
                "ios.danmakuEnabled": .bool(danmakuEnabled),
                "ios.danmakuLoadEnabled": .bool(danmakuLoadEnabled),
                HTTPUserAgent.preferenceKey: .string(globalUserAgent),
                "ios.catalogDisplaySize": .number(Double(catalogDisplaySize.rawValue)),
                "ios.adHostBlockingEnabled": .bool(adHostBlockingEnabled),
                "ios.selectedVodSiteKey": .string(currentVodSiteKey),
                "ios.selectedLiveSourceName": .string(selectedLiveSourceName),
                "ios.selectedLiveSourceURL": .string(selectedLiveSourceURL),
                "player_engine": .number(androidPlayerEngineValue),
                "incognito": .bool(incognito),
                "change": .bool(automaticLineChange),
                "speed": .number(longPressPlaybackSpeed),
                "size": .number(Double(catalogDisplaySize.rawValue)),
                "scale": .number(Double(defaultAspectMode.rawValue)),
                "scale_live": .number(Double(liveAspectMode.rawValue)),
                "subtitle_text_size": .number(subtitleTextSize),
                "subtitle_position": .number(subtitleBottomOffset),
                "danmaku_show": .bool(danmakuEnabled),
                "danmaku_load": .bool(danmakuLoadEnabled),
                "ad_host_block": .bool(adHostBlockingEnabled),
                "ua": .string(globalUserAgent)
            ]
        )
    }

    private var androidPlayerEngineValue: Double {
        switch playerPreference {
        case .avPlayer: return 0
        case .mdk: return 1
        case .mpv: return 2
        }
    }

    public func reloadLiveSources() {
        if !liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadLiveConfiguration()
        } else {
            loadLiveSources(configuration.lives)
        }
    }

    public func loadEPG(for live: Live, channel: Channel) async throws -> [Epg] {
        guard let liveRepository else { return [] }
        return try await liveRepository.loadEPG(for: live, channel: channel)
    }

    public func livePlaybackRequest(
        live: Live,
        channel: Channel,
        line: Int = 0,
        programme: EpgData? = nil
    ) throws -> PlaybackRequest {
        guard channel.urls.indices.contains(line) else {
            throw LiveRepositoryError.invalidURL(channel.urls.first ?? "")
        }
        let rawValue = channel.urls[line]
        var value = rawValue.split(separator: "$", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rawValue
        let catchup = channel.catchup ?? live.catchup
        if let programme,
           let catchup,
           let replay = catchup.replayURL(
               baseURL: value,
               programme: programme,
               timeZone: TimeZone(identifier: live.timeZone) ?? .current
           ) {
            value = replay
        }
        guard let url = URL(string: value), url.scheme != nil else {
            throw LiveRepositoryError.invalidURL(value)
        }
        var headers = live.header.merging(channel.header) { _, channelValue in channelValue }
        let userAgent = channel.userAgent.isEmpty ? live.userAgent : channel.userAgent
        let origin = channel.origin.isEmpty ? live.origin : channel.origin
        let referer = channel.referer.isEmpty ? live.referer : channel.referer
        if !userAgent.isEmpty { headers["User-Agent"] = userAgent }
        if !origin.isEmpty { headers["Origin"] = origin }
        if !referer.isEmpty { headers["Referer"] = referer }
        headers = HTTPUserAgent.applyingDefault(to: headers, value: globalUserAgent)
        return PlaybackRequest(
            url: value,
            headers: headers,
            format: channel.format,
            artwork: channel.logo,
            mediaType: "live",
            drm: channel.drm,
            timeout: TimeInterval(live.timeout > 0 ? live.timeout : 15),
            enginePreference: playerPreference
        )
    }

    @discardableResult
    public func toggleLiveKeep(live: Live, channel: Channel) -> Bool {
        guard let persistence else { return false }
        let keep = Keep(
            key: liveKeepKey(live: live, channel: channel),
            siteName: live.name,
            vodName: channel.name,
            vodPic: channel.logo,
            createTime: Int64(Date().timeIntervalSince1970 * 1000),
            type: 1
        )
        let selected = (try? persistence.toggleKeep(keep)) ?? false
        reloadPersistence()
        return selected
    }

    public func isLiveKept(live: Live, channel: Channel) -> Bool {
        keeps.contains { $0.type == 1 && $0.key == liveKeepKey(live: live, channel: channel) }
    }

    public func history(for vod: Vod, site: Site? = nil) -> History? {
        histories.first { $0.key == historyKey(for: vod, site: site ?? selectedSite) }
    }

    public func savePlayback(
        vod: Vod,
        route: PlaybackRoute,
        episode: PlaybackEpisode,
        time: PlayerTime,
        speed: Double = 1,
        reverseSort: Bool? = nil,
        opening: Int64? = nil,
        ending: Int64? = nil,
        scale: Int? = nil,
        site: Site? = nil
    ) {
        guard !incognito, let persistence else { return }
        let key = historyKey(for: vod, site: site ?? selectedSite)
        var history = (try? persistence.history(key: key)) ?? History(key: key, vodName: vod.vodName, vodPic: vod.vodPic)
        history.vodName = vod.vodName
        history.vodPic = vod.vodPic
        history.vodFlag = route.name
        history.vodRemarks = episode.name
        history.episodeURL = episode.url
        history.createTime = Int64(Date().timeIntervalSince1970 * 1000)
        history.position = Int64(time.position * 1000)
        history.duration = Int64(time.duration * 1000)
        history.speed = speed
        if let reverseSort { history.reverseSort = reverseSort }
        if let opening { history.opening = opening }
        if let ending { history.ending = ending }
        if let scale { history.scale = scale }
        try? persistence.saveHistory(history)
        reloadPersistence()
    }

    @discardableResult
    public func toggleKeep(vod: Vod, site: Site? = nil) -> Bool {
        guard let persistence else { return false }
        let sourceSite = site ?? selectedSite
        let keep = Keep(
            key: historyKey(for: vod, site: sourceSite),
            siteName: sourceSite.name,
            vodName: vod.vodName,
            vodPic: vod.vodPic,
            createTime: Int64(Date().timeIntervalSince1970 * 1000)
        )
        let selected = (try? persistence.toggleKeep(keep)) ?? false
        reloadPersistence()
        return selected
    }

    public func isKept(_ vod: Vod, site: Site? = nil) -> Bool {
        keeps.contains { $0.key == historyKey(for: vod, site: site ?? selectedSite) }
    }

    public func vod(from keep: Keep) -> Vod {
        Vod(vodID: keep.key.components(separatedBy: "@@@").last ?? keep.key, vodName: keep.vodName, vodPic: keep.vodPic)
    }

    public func vod(from history: History) -> Vod {
        Vod(vodID: history.key.components(separatedBy: "@@@").last ?? history.key, vodName: history.vodName, vodPic: history.vodPic, vodRemarks: history.vodRemarks)
    }

    private func loadConfiguration(loadConfiguredLiveSource: Bool = true) {
        guard let repository, let url = URL(string: vodConfigURL) else {
            configurationSaveState = .invalid
            return
        }
        configurationTask?.cancel()
        catalogTask?.cancel()
        configurationSaveState = .loading
        catalogState = .loading
        configurationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let document = try await repository.loadConfig(from: url)
                try Task.checkCancellation()
                guard let first = document.sites.first(where: { $0.hide != 1 }) else {
                    throw VodRepositoryError.invalidSite
                }
                try persistence?.replaceConfiguration(document, sourceURL: url.absoluteString)
                configuration = document
                networkPolicyStore?.apply(document)
                liveSources = document.lives
                let restoredSite = retainedVodSite(in: document.sites, fallback: first)
                selectedSite = restoredSite
                selectedVodSiteKey = restoredSite.key
                configurationSaveState = .saved
                reloadPersistence()
                loadHome()
                if loadConfiguredLiveSource {
                    if !liveConfigURL.isEmpty {
                        loadLiveConfiguration(updateConfigurationState: true)
                    } else {
                        loadLiveSources(document.lives)
                    }
                }
            } catch is CancellationError {
            } catch {
                configurationSaveState = .failed(error.localizedDescription)
                catalogState = .failed(error.localizedDescription)
            }
        }
    }

    private func loadHome() {
        guard let repository, !selectedSite.key.isEmpty else { return }
        catalogTask?.cancel()
        catalogLoadingMore = false
        catalogCanLoadMore = false
        catalogPage = 1
        catalogPageCount = 1
        catalogState = .loading
        catalogTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await repository.home(site: selectedSite, includeFilters: true)
                try Task.checkCancellation()
                categories = filteredCategories(result.classes)
                filters = result.filters
                selectedCategory = categories.first ?? VodClass()
                selectedFilters = defaultFilterValues(result.filters[selectedCategory.typeID] ?? [])
                catalogState = result.list.isEmpty ? .empty : .loaded(result.list)
            } catch is CancellationError {
            } catch {
                catalogState = .failed(error.localizedDescription)
            }
        }
    }

    private func loadLiveConfiguration(updateConfigurationState: Bool = false) {
        guard let liveRepository else {
            liveState = .failed("直播服务尚未初始化")
            return
        }
        let value = liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            loadLiveSources(configuration.lives)
            return
        }
        liveTask?.cancel()
        liveState = .loading
        liveTask = Task { [weak self] in
            guard let self else { return }
            do {
                let name = URL(string: value)?.deletingPathExtension().lastPathComponent ?? "直播"
                let loaded = try await liveRepository.load(Live(name: name.isEmpty ? "直播" : name, url: value))
                try Task.checkCancellation()
                liveSources = [loaded]
                liveState = loaded.groups.flatMap(\.channels).isEmpty ? .empty : .loaded
                retainSelectedLiveSource(in: liveSources)
                if let persistence {
                    do {
                        let data = try JSONEncoder().encode(loaded)
                        try persistence.saveConfigurationRecord(ConfigRecord(
                            type: 1,
                            time: Int64(Date().timeIntervalSince1970 * 1000),
                            url: value,
                            json: String(data: data, encoding: .utf8) ?? "",
                            name: loaded.name.isEmpty ? "直播" : loaded.name
                        ))
                        configurationHistoryError = ""
                        reloadPersistence()
                    } catch {
                        configurationHistoryError = error.localizedDescription
                    }
                }
                if updateConfigurationState { configurationSaveState = .saved }
            } catch is CancellationError {
            } catch {
                liveState = .failed(error.localizedDescription)
                if updateConfigurationState { configurationSaveState = .failed(error.localizedDescription) }
            }
        }
    }

    private func loadLiveSources(_ sources: [Live]) {
        guard let liveRepository else {
            liveSources = sources
            liveState = sources.flatMap(\.groups).flatMap(\.channels).isEmpty ? .empty : .loaded
            retainSelectedLiveSource(in: liveSources)
            return
        }
        liveTask?.cancel()
        guard !sources.isEmpty else {
            liveSources = []
            liveState = .empty
            return
        }
        liveState = .loading
        liveTask = Task { [weak self] in
            guard let self else { return }
            do {
                var loaded: [Live] = []
                for source in sources {
                    loaded.append(try await liveRepository.load(source))
                    try Task.checkCancellation()
                }
                liveSources = loaded
                liveState = loaded.flatMap(\.groups).flatMap(\.channels).isEmpty ? .empty : .loaded
                retainSelectedLiveSource(in: liveSources)
            } catch is CancellationError {
            } catch {
                liveSources = sources
                liveState = .failed(error.localizedDescription)
            }
        }
    }

    private func loadCategory(_ category: VodClass) {
        guard let repository, !category.typeID.isEmpty else { return }
        catalogTask?.cancel()
        catalogLoadingMore = false
        catalogCanLoadMore = false
        catalogPage = 1
        catalogPageCount = 1
        catalogState = .loading
        catalogTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await repository.category(site: selectedSite, typeID: category.typeID, page: 1, filters: selectedFilters)
                try Task.checkCancellation()
                if !result.filters.isEmpty { filters = result.filters }
                catalogPageCount = max(result.pageCount, 1)
                catalogCanLoadMore = catalogPage < catalogPageCount
                catalogState = result.list.isEmpty ? .empty : .loaded(result.list)
            } catch is CancellationError {
            } catch {
                catalogState = .failed(error.localizedDescription)
            }
        }
    }

    private func filteredCategories(_ values: [VodClass]) -> [VodClass] {
        guard !selectedSite.categories.isEmpty else { return values }
        let selected = Set(selectedSite.categories)
        return values.filter { selected.contains($0.typeName) }
    }

    private func defaultFilterValues(_ values: [VodFilter]) -> [String: String] {
        values.reduce(into: [String: String]()) { result, filter in
            guard !filter.initialValue.isEmpty else { return }
            result[filter.key] = filter.initialValue
        }
    }

    private func reloadPersistence() {
        guard let persistence else { return }
        keeps = (try? persistence.loadKeeps()) ?? []
        histories = (try? persistence.loadHistories(limit: 100)) ?? []
        do {
            configurationHistory = try persistence.loadConfigurations()
            configurationHistoryError = ""
        } catch {
            configurationHistory = []
            configurationHistoryError = error.localizedDescription
        }
    }

    private func retainSelectedLiveSource(in sources: [Live]) {
        let byURL = selectedLiveSourceURL.isEmpty
            ? nil
            : sources.first(where: { $0.url == selectedLiveSourceURL })
        let byName = selectedLiveSourceName.isEmpty
            ? nil
            : sources.first(where: { $0.name == selectedLiveSourceName })
        guard let selected = byURL ?? byName ?? sources.first else {
            selectedLiveSourceName = ""
            selectedLiveSourceURL = ""
            return
        }
        selectedLiveSourceName = selected.name
        selectedLiveSourceURL = selected.url
    }

    private func retainedVodSite(in sites: [Site], fallback: Site) -> Site {
        if let selected = sites.first(where: { $0.key == selectedVodSiteKey && $0.hide != 1 }) {
            return selected
        }
        if let selected = sites.first(where: { $0.key == selectedSite.key && $0.hide != 1 }) {
            return selected
        }
        return fallback
    }

    private func historyKey(for vod: Vod, site: Site) -> String {
        "\(site.key)@@@\(vod.vodID)"
    }

    private func liveKeepKey(live: Live, channel: Channel) -> String {
        "\(live.name)@@@\(channel.id)"
    }

    private func isValidOptionalURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}

private struct AggregateSearchOutcome: @unchecked Sendable {
    var index: Int
    var site: Site
    var result: VodResult?
    var errorMessage: String?
}
