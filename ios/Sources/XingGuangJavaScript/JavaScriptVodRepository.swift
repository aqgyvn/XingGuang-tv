import Foundation
import XingGuangKit

public final class JavaScriptVodRepository: VodRepository, @unchecked Sendable {
    private let configRepository: ApiVodRepository
    private let store: JavaScriptRuntimeStore

    public init(
        configRepository: ApiVodRepository = ApiVodRepository(),
        transport: JavaScriptHTTPTransport = URLSessionJavaScriptHTTPTransport(),
        defaults: UserDefaults = .standard,
        proxyEndpoint: URL? = nil
    ) {
        self.configRepository = configRepository
        self.store = JavaScriptRuntimeStore(
            transport: transport,
            defaults: defaults,
            proxyEndpoint: proxyEndpoint
        )
    }

    public func loadConfig(from url: URL) async throws -> VodConfigDocument {
        try await configRepository.loadConfig(from: url)
    }

    public func home(site: Site, includeFilters: Bool = true) async throws -> VodResult {
        let runtime = try await runtime(for: site)
        let home = try decodeResult(await runtime.call("home", arguments: [includeFilters]))
        let homeVod = try decodeResult(await runtime.call("homeVod", arguments: []))
        return VodResult(
            classes: home.classes,
            list: homeVod.list.isEmpty ? home.list : homeVod.list,
            filters: includeFilters ? home.filters : [:],
            message: home.message,
            pageCount: homeVod.pageCount == 0 ? home.pageCount : homeVod.pageCount
        )
    }

    public func category(site: Site, typeID: String, page: Int = 1, filters: [String: String] = [:]) async throws -> VodResult {
        let runtime = try await runtime(for: site)
        let extend = filters.reduce(into: [String: Any]()) { result, item in result[item.key] = item.value }
        return try decodeResult(await runtime.call(
            "category",
            arguments: [typeID, String(max(page, 1)), true, extend]
        ))
    }

    public func search(site: Site, keyword: String, page: Int = 1) async throws -> VodResult {
        let runtime = try await runtime(for: site)
        let arguments: [Any] = page > 1 ? [keyword, false, String(page)] : [keyword, false]
        return try decodeResult(await runtime.call("search", arguments: arguments))
    }

    public func detail(site: Site, vodID: String) async throws -> VodResult {
        let runtime = try await runtime(for: site)
        return try decodeResult(await runtime.call("detail", arguments: [vodID]))
    }

    public func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        let runtime = try await runtime(for: site)
        let raw = try await runtime.call("play", arguments: [flag, episodeURL, []])
        let result = try decodeResult(raw)
        let url = result.url.isEmpty ? result.list.first?.playbackRoutes.first?.episodes.first?.url ?? "" : result.url
        guard !url.isEmpty, URL(string: url)?.scheme != nil else {
            throw VodRepositoryError.invalidResponse
        }
        return PlaybackRequest(
            url: url,
            headers: site.header.merging(result.header) { _, new in new },
            format: result.format,
            artwork: result.artwork,
            subtitles: result.subtitles,
            danmaku: result.danmaku,
            drm: result.drm,
            timeout: TimeInterval(site.timeout > 0 ? site.timeout : 15),
            requiresSniffing: result.parse != 0,
            sniffScript: site.click
        )
    }

    public func isVideo(site: Site, url: String) async throws -> Bool {
        let runtime = try await runtime(for: site)
        let raw = try await runtime.call("isVideo", arguments: [url])
        return try JavaScriptSpiderProtocolCodec.boolean(raw, method: "isVideo")
    }

    public func sniffer(site: Site) async throws -> Bool {
        let runtime = try await runtime(for: site)
        let raw = try await runtime.call("sniffer", arguments: [])
        return try JavaScriptSpiderProtocolCodec.boolean(raw, method: "sniffer")
    }

    public func action(site: Site, value: String) async throws -> String {
        let runtime = try await runtime(for: site)
        let raw = try await runtime.call("action", arguments: [value])
        return try JavaScriptSpiderProtocolCodec.string(raw, method: "action")
    }

    /// Loads a JavaScript Spider live source using Android's liveContent(url)
    /// contract. The returned string is intentionally left untouched so the
    /// shared JSON/M3U/TXT live parser can handle the source format.
    public func liveContent(site: Site, url: String) async throws -> String {
        let runtime = try await runtime(for: site)
        let raw = try await runtime.call("live", arguments: [url])
        return try JavaScriptSpiderProtocolCodec.string(raw, method: "live")
    }

    public func proxy(site: Site, parameters: [String: String]) async throws -> JavaScriptProxyResponse {
        let runtime = try await runtime(for: site)
        let raw: String
        if parameters["from"]?.lowercased() == "catvod" {
            guard let url = parameters["url"], !url.isEmpty else {
                throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
            }
            var segments = url.components(separatedBy: "/")
            while segments.last?.isEmpty == true {
                segments.removeLast()
            }
            let headers = jsonObject(parameters["header"] ?? "{}")
            raw = try await runtime.call("proxy", arguments: [segments, headers])
        } else {
            raw = try await runtime.call("proxy", arguments: [parameters])
        }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            throw JavaScriptSpiderProtocolError.unsupportedMethod("proxy")
        }
        return try JavaScriptSpiderProtocolCodec.proxy(raw)
    }

    public func proxy(parameters: [String: String]) async throws -> JavaScriptProxyResponse {
        guard let site = await store.site(key: parameters["siteKey"]) else {
            throw JavaScriptSpiderProtocolError.invalidResponse("proxy site")
        }
        return try await proxy(site: site, parameters: parameters)
    }

    public func setProxyEndpoint(_ endpoint: URL) {
        store.endpoint.value = endpoint
    }

    public func invalidate(site: Site) {
        let key = runtimeKey(for: site)
        Task { await store.remove(key: key) }
    }

    private func runtime(for site: Site) async throws -> QuickJSRuntime {
        guard site.type == 3 else { throw VodRepositoryError.unsupportedSiteType(site.type) }
        let api = site.api.lowercased()
        if api.hasPrefix("csp_") {
            throw VodRepositoryError.unsupportedDependency("Android JAR Spider（csp_）")
        }
        if api.hasSuffix(".py") {
            throw VodRepositoryError.unsupportedDependency("Python Spider（Chaquopy）")
        }
        guard !site.api.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VodRepositoryError.invalidSite
        }
        let key = runtimeKey(for: site)
        let runtime = await store.runtime(for: site, key: key)
        do {
            try await runtime.initialize()
            return runtime
        } catch {
            await store.remove(key: key)
            throw error
        }
    }

    private func runtimeKey(for site: Site) -> String {
        "\(site.key)|\(site.api)|\(site.ext?.stringValue ?? "")"
    }

    private func decodeResult(_ raw: String) throws -> VodResult {
        guard let data = raw.data(using: .utf8) else { throw VodRepositoryError.invalidResponse }
        do {
            return try JSONDecoder().decode(VodResult.self, from: data)
        } catch {
            throw VodRepositoryError.invalidResponse
        }
    }

    private func jsonObject(_ value: String) -> Any {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return [:]
        }
        return object
    }
}

private actor JavaScriptRuntimeStore {
    private let transport: JavaScriptHTTPTransport
    private let defaults: UserDefaults
    nonisolated let endpoint: JavaScriptProxyEndpoint
    private var runtimes: [String: QuickJSRuntime] = [:]
    private var sites: [String: Site] = [:]
    private var recentSiteKey: String?

    init(transport: JavaScriptHTTPTransport, defaults: UserDefaults, proxyEndpoint: URL?) {
        self.transport = transport
        self.defaults = defaults
        self.endpoint = JavaScriptProxyEndpoint(value: proxyEndpoint)
    }

    func runtime(for site: Site, key: String) -> QuickJSRuntime {
        sites[site.key] = site
        recentSiteKey = site.key
        if let runtime = runtimes[key] { return runtime }
        let runtime = QuickJSRuntime(
            site: site,
            transport: transport,
            defaults: defaults,
            proxyEndpoint: endpoint
        )
        runtimes[key] = runtime
        return runtime
    }

    func site(key: String?) -> Site? {
        if let key, let site = sites[key] { return site }
        guard let recentSiteKey else { return nil }
        return sites[recentSiteKey]
    }

    func remove(key: String) async {
        guard let runtime = runtimes.removeValue(forKey: key) else { return }
        await runtime.dispose()
    }
}

public final class RoutingVodRepository: VodRepository, @unchecked Sendable {
    private let api: ApiVodRepository
    private let javascript: JavaScriptVodRepository

    public init(api: ApiVodRepository = ApiVodRepository(), javascript: JavaScriptVodRepository = JavaScriptVodRepository()) {
        self.api = api
        self.javascript = javascript
    }

    public func loadConfig(from url: URL) async throws -> VodConfigDocument {
        try await api.loadConfig(from: url)
    }

    public func home(site: Site, includeFilters: Bool = true) async throws -> VodResult {
        try await repository(for: site).home(site: site, includeFilters: includeFilters)
    }

    public func category(site: Site, typeID: String, page: Int = 1, filters: [String: String] = [:]) async throws -> VodResult {
        try await repository(for: site).category(site: site, typeID: typeID, page: page, filters: filters)
    }

    public func search(site: Site, keyword: String, page: Int = 1) async throws -> VodResult {
        try await repository(for: site).search(site: site, keyword: keyword, page: page)
    }

    public func detail(site: Site, vodID: String) async throws -> VodResult {
        try await repository(for: site).detail(site: site, vodID: vodID)
    }

    public func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        try await repository(for: site).resolvePlayback(site: site, flag: flag, episodeURL: episodeURL)
    }

    private func repository(for site: Site) throws -> VodRepository {
        switch site.type {
        case 0, 1, 4:
            return api
        case 3:
            return javascript
        default:
            throw VodRepositoryError.unsupportedSiteType(site.type)
        }
    }
}
