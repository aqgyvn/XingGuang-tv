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

@MainActor
public final class XingGuangAppModel: ObservableObject {
    @Published public var selectedSite: Site
    @Published public var selectedCategory: VodClass
    @Published public private(set) var categories: [VodClass]
    @Published public private(set) var catalogState: CatalogState
    @Published public var vodConfigURL: String
    @Published public var liveConfigURL: String
    @Published public private(set) var configurationSaveState: ConfigurationSaveState = .idle
    @Published public private(set) var liveSources: [Live]
    @Published public private(set) var keeps: [Keep]
    @Published public private(set) var histories: [History]
    @Published public var playerPreference: PlayerEnginePreference {
        didSet { defaults.set(playerPreference.rawValue, forKey: "ios.playerEngine") }
    }

    public var continueWatching: History? { histories.first }
    public var repositoryAvailable: Bool { repository != nil }
    public private(set) var configuration: VodConfigDocument

    private let repository: VodRepository?
    private let persistence: PersistenceStore?
    private let playerFactory: PlayerEngineFactory
    private let defaults: UserDefaults
    private var configurationTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?

    public init(
        selectedSite: Site = PreviewFixtures.site,
        categories: [VodClass] = PreviewFixtures.categories,
        catalogState: CatalogState = .loaded(PreviewFixtures.vods),
        liveSources: [Live] = PreviewFixtures.config.lives,
        continueWatching: History? = PreviewFixtures.history,
        keeps: [Keep] = PreviewFixtures.keeps,
        defaults: UserDefaults = .standard,
        repository: VodRepository? = nil,
        persistence: PersistenceStore? = nil,
        playerFactory: PlayerEngineFactory = PreviewPlayerEngineFactory(),
        usePreviewData: Bool = true
    ) {
        self.repository = repository
        self.persistence = persistence
        self.playerFactory = playerFactory
        self.defaults = defaults
        self.vodConfigURL = defaults.string(forKey: "ios.vodConfigURL") ?? ""
        self.liveConfigURL = defaults.string(forKey: "ios.liveConfigURL") ?? ""
        self.playerPreference = PlayerEnginePreference(rawValue: defaults.string(forKey: "ios.playerEngine") ?? "") ?? .automatic

        if usePreviewData {
            self.configuration = PreviewFixtures.config
            self.selectedSite = selectedSite
            self.categories = categories
            self.selectedCategory = categories.first ?? VodClass(typeID: "all", typeName: "全部")
            self.catalogState = catalogState
            self.liveSources = liveSources
            self.keeps = keeps
            self.histories = continueWatching.map { [$0] } ?? []
        } else {
            let emptyCategory = VodClass(typeID: "", typeName: "")
            self.configuration = VodConfigDocument()
            self.selectedSite = Site()
            self.categories = []
            self.selectedCategory = emptyCategory
            self.catalogState = .empty
            self.liveSources = []
            self.keeps = []
            self.histories = []
        }
    }

    public func bootstrap() {
        reloadPersistence()
        if !vodConfigURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadConfiguration()
        }
    }

    public func selectCategory(_ category: VodClass) {
        selectedCategory = category
        loadCategory(category)
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
        guard repository != nil, !vodConfigURL.isEmpty else {
            configurationSaveState = .saved
            return
        }
        loadConfiguration()
    }

    public func resetConfigurationSaveState() {
        configurationSaveState = .idle
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
        request.enginePreference = playerPreference
        return request
    }

    public func makePlayerSession() -> PlayerSession {
        PlayerSession(engine: playerFactory.makePlayer(preference: playerPreference))
    }

    public func history(for vod: Vod) -> History? {
        histories.first { $0.key == historyKey(for: vod) }
    }

    public func savePlayback(vod: Vod, route: PlaybackRoute, episode: PlaybackEpisode, time: PlayerTime, speed: Double = 1) {
        guard let persistence else { return }
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
                liveSources = document.lives
                selectedSite = document.sites.first(where: { $0.key == selectedSite.key && $0.hide != 1 }) ?? first
                configurationSaveState = .saved
                reloadPersistence()
                loadHome()
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
                selectedCategory = categories.first ?? VodClass()
                catalogState = result.list.isEmpty ? .empty : .loaded(result.list)
            } catch is CancellationError {
            } catch {
                catalogState = .failed(error.localizedDescription)
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
                let result = try await repository.category(site: selectedSite, typeID: category.typeID, page: 1, filters: [:])
                try Task.checkCancellation()
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

    private func reloadPersistence() {
        guard let persistence else { return }
        keeps = (try? persistence.loadKeeps()) ?? []
        histories = (try? persistence.loadHistories(limit: 100)) ?? []
    }

    private func historyKey(for vod: Vod) -> String {
        "\(selectedSite.key)@@@\(vod.vodID)"
    }

    private func isValidOptionalURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}
