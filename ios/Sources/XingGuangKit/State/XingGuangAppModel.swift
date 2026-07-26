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

@MainActor
public final class XingGuangAppModel: ObservableObject {
    @Published public var selectedSite: Site
    @Published public var selectedCategory: VodClass
    @Published public private(set) var categories: [VodClass]
    @Published public private(set) var filters: [String: [VodFilter]]
    @Published public var selectedFilters: [String: String]
    @Published public private(set) var catalogState: CatalogState
    @Published public var vodConfigURL: String
    @Published public var liveConfigURL: String
    @Published public private(set) var configurationSaveState: ConfigurationSaveState = .idle
    @Published public private(set) var liveSources: [Live]
    @Published public private(set) var liveState: LiveLoadState
    @Published public private(set) var keeps: [Keep]
    @Published public private(set) var histories: [History]
    @Published public var incognito: Bool {
        didSet { defaults.set(incognito, forKey: "ios.incognito") }
    }
    @Published public var automaticLineChange: Bool {
        didSet { defaults.set(automaticLineChange, forKey: "ios.automaticLineChange") }
    }
    @Published public var defaultPlaybackSpeed: Double {
        didSet { defaults.set(defaultPlaybackSpeed, forKey: "ios.defaultPlaybackSpeed") }
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
    private var configurationTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?

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
        self.incognito = defaults.object(forKey: "ios.incognito") as? Bool ?? false
        self.automaticLineChange = defaults.object(forKey: "ios.automaticLineChange") as? Bool ?? true
        let storedSpeed = defaults.object(forKey: "ios.defaultPlaybackSpeed") as? Double ?? 1
        self.defaultPlaybackSpeed = min(max(storedSpeed, 0.5), 2)
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
        }
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

    public func selectSite(_ site: Site) {
        guard selectedSite.key != site.key else { return }
        selectedSite = site
        loadHome()
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

    public func resetConfigurationSaveState() {
        configurationSaveState = .idle
    }

    public func reloadPreferences() {
        incognito = defaults.object(forKey: "ios.incognito") as? Bool ?? incognito
        automaticLineChange = defaults.object(forKey: "ios.automaticLineChange") as? Bool ?? automaticLineChange
        defaultPlaybackSpeed = min(max(defaults.object(forKey: "ios.defaultPlaybackSpeed") as? Double ?? defaultPlaybackSpeed, 0.5), 2)
        playerPreference = PlayerEnginePreference(rawValue: defaults.string(forKey: "ios.playerEngine") ?? "") ?? playerPreference
        subtitleTextSize = min(max(defaults.object(forKey: "ios.subtitleTextSize") as? Double ?? subtitleTextSize, 14), 42)
        subtitleBottomOffset = min(max(defaults.object(forKey: "ios.subtitleBottomOffset") as? Double ?? subtitleBottomOffset, 8), 120)
        danmakuEnabled = defaults.object(forKey: "ios.danmakuEnabled") as? Bool ?? danmakuEnabled
    }

    public func search(keyword: String, page: Int = 1) async throws -> [Vod] {
        guard let repository, !selectedSite.key.isEmpty else { return [] }
        return try await repository.search(site: selectedSite, keyword: keyword, page: page).list
    }

    public func detail(for vod: Vod) async throws -> Vod {
        guard let repository, !selectedSite.key.isEmpty else { return vod }
        return try await repository.detail(site: selectedSite, vodID: vod.vodID).list.first ?? vod
    }

    public func resolvePlayback(route: PlaybackRoute, episode: PlaybackEpisode) async throws -> PlaybackRequest {
        guard let repository else { return PlaybackRequest(url: episode.url) }
        var request = try await repository.resolvePlayback(site: selectedSite, flag: route.name, episodeURL: episode.url)
        if request.requiresSniffing {
            guard let webMediaSniffer else {
                throw VodRepositoryError.unsupportedPlayback("当前运行环境未配置网页媒体嗅探器")
            }
            request = try await webMediaSniffer.resolve(request, site: selectedSite)
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
        var configs: [ConfigRecord] = []
        let vodURL = vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vodURL.isEmpty {
            let data = try encoder.encode(configuration)
            configs.append(ConfigRecord(
                type: 0,
                time: now,
                url: vodURL,
                json: String(data: data, encoding: .utf8) ?? "",
                name: "点播",
                logo: configuration.logo,
                home: selectedSite.key
            ))
        }
        let liveURL = liveConfigURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveURL.isEmpty {
            let data = try encoder.encode(liveSources)
            configs.append(ConfigRecord(
                type: 1,
                time: now,
                url: liveURL,
                json: String(data: data, encoding: .utf8) ?? "",
                name: "直播"
            ))
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
                "ios.subtitleTextSize": .number(subtitleTextSize),
                "ios.subtitleBottomOffset": .number(subtitleBottomOffset),
                "ios.danmakuEnabled": .bool(danmakuEnabled),
                "player_engine": .number(androidPlayerEngineValue),
                "incognito": .bool(incognito),
                "change": .bool(automaticLineChange),
                "subtitle_text_size": .number(subtitleTextSize),
                "subtitle_position": .number(subtitleBottomOffset),
                "danmaku_show": .bool(danmakuEnabled)
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

    public func history(for vod: Vod) -> History? {
        histories.first { $0.key == historyKey(for: vod) }
    }

    public func savePlayback(vod: Vod, route: PlaybackRoute, episode: PlaybackEpisode, time: PlayerTime, speed: Double = 1) {
        guard !incognito, let persistence else { return }
        var history = History(key: historyKey(for: vod), vodName: vod.vodName, vodPic: vod.vodPic)
        history.vodFlag = route.name
        history.vodRemarks = episode.name
        history.episodeURL = episode.url
        history.createTime = Int64(Date().timeIntervalSince1970 * 1000)
        history.position = Int64(time.position * 1000)
        history.duration = Int64(time.duration * 1000)
        history.speed = speed
        try? persistence.saveHistory(history)
        reloadPersistence()
    }

    @discardableResult
    public func toggleKeep(vod: Vod) -> Bool {
        guard let persistence else { return false }
        let keep = Keep(
            key: historyKey(for: vod),
            siteName: selectedSite.name,
            vodName: vod.vodName,
            vodPic: vod.vodPic,
            createTime: Int64(Date().timeIntervalSince1970 * 1000)
        )
        let selected = (try? persistence.toggleKeep(keep)) ?? false
        reloadPersistence()
        return selected
    }

    public func isKept(_ vod: Vod) -> Bool {
        keeps.contains { $0.key == historyKey(for: vod) }
    }

    public func vod(from keep: Keep) -> Vod {
        Vod(vodID: keep.key.components(separatedBy: "@@@").last ?? keep.key, vodName: keep.vodName, vodPic: keep.vodPic)
    }

    public func vod(from history: History) -> Vod {
        Vod(vodID: history.key.components(separatedBy: "@@@").last ?? history.key, vodName: history.vodName, vodPic: history.vodPic, vodRemarks: history.vodRemarks)
    }

    private func loadConfiguration() {
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
                selectedSite = document.sites.first(where: { $0.key == selectedSite.key && $0.hide != 1 }) ?? first
                configurationSaveState = .saved
                reloadPersistence()
                loadHome()
                if !liveConfigURL.isEmpty {
                    loadLiveConfiguration(updateConfigurationState: true)
                } else {
                    loadLiveSources(document.lives)
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
        catalogState = .loading
        catalogTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await repository.category(site: selectedSite, typeID: category.typeID, page: 1, filters: selectedFilters)
                try Task.checkCancellation()
                if !result.filters.isEmpty { filters = result.filters }
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
    }

    private func historyKey(for vod: Vod) -> String {
        "\(selectedSite.key)@@@\(vod.vodID)"
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
