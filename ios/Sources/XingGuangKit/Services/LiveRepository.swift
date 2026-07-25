import Foundation

public enum LiveRepositoryError: Error, Equatable, LocalizedError {
    case emptySource
    case invalidURL(String)
    case unsupportedScheme(String)
    case unsupportedDynamicSource(String)
    case localReadFailed(String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .emptySource: return "The live source is empty."
        case .invalidURL(let value): return "The live source URL is invalid: \(value)"
        case .unsupportedScheme(let value): return "The live source scheme is not supported: \(value)"
        case .unsupportedDynamicSource(let value): return "iOS 暂不支持此动态直播来源：\(value)"
        case .localReadFailed(let value): return "The local live source could not be read: \(value)"
        case .emptyResponse: return "The live source returned an empty response."
        }
    }
}

public typealias LiveDynamicContentLoader = (Live) async throws -> String

public protocol LiveRepository {
    func load(_ live: Live) async throws -> Live
    func loadEPG(for live: Live, channel: Channel?) async throws -> [Epg]
}

/// Loads a Live entry from inline groups, a local file, or an HTTP(S) source.
public final class DefaultLiveRepository: LiveRepository, @unchecked Sendable {
    private let client: HTTPClient
    private let dynamicContentLoader: LiveDynamicContentLoader?

    public init(
        client: HTTPClient = URLSessionHTTPClient(),
        dynamicContentLoader: LiveDynamicContentLoader? = nil
    ) {
        self.client = client
        self.dynamicContentLoader = dynamicContentLoader
    }

    public func load(_ live: Live) async throws -> Live {
        if !live.groups.isEmpty {
            return LivePlaylistParser.applyingDefaults(live)
        }
        guard !live.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LiveRepositoryError.emptySource
        }

        // Android routes live entries with an `api` field through the Spider
        // liveContent(url) contract instead of fetching the URL directly.
        if !live.api.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let dynamicContentLoader else {
                throw LiveRepositoryError.unsupportedDynamicSource(live.api)
            }
            let content = try await dynamicContentLoader(live)
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LiveRepositoryError.emptyResponse
            }
            return try LivePlaylistParser.parse(content, into: live, sourceURL: URL(string: live.url))
        }

        if let inline = inlineData(live.url) {
            return try LivePlaylistParser.parse(inline, into: live)
        }
        let (data, sourceURL) = try await read(live.url, headers: requestHeaders(for: live), timeout: live.timeout > 0 ? TimeInterval(live.timeout) : 15)
        guard !data.isEmpty else { throw LiveRepositoryError.emptyResponse }
        return try LivePlaylistParser.parse(data, into: live, sourceURL: sourceURL)
    }

    public func loadEPG(for live: Live, channel: Channel? = nil) async throws -> [Epg] {
        var source = live.epg.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty, let channel, !channel.epg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            source = channel.epg.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !source.isEmpty else { return [] }
        if let channel {
            source = source
                .replacingOccurrences(of: "{id}", with: channel.tvgID.isEmpty ? channel.name : channel.tvgID)
                .replacingOccurrences(of: "{name}", with: channel.tvgName.isEmpty ? channel.name : channel.tvgName)
                .replacingOccurrences(of: "{epg}", with: channel.epg)
        }
        let keys: Set<String>?
        if let channel {
            keys = Set([channel.name, channel.tvgID, channel.tvgName].filter { !$0.isEmpty })
        } else {
            keys = nil
        }
        let data: Data
        if let inline = inlineData(source) ?? (source.hasPrefix("<") ? source.data(using: .utf8) : nil) {
            data = inline
        } else {
            let response = try await read(source, headers: requestHeaders(for: live), timeout: live.timeout > 0 ? TimeInterval(live.timeout) : 15)
            data = response.data
        }
        guard !data.isEmpty else { throw LiveRepositoryError.emptyResponse }
        return try EpgParser.parse(data, channelKeys: keys)
    }

    public func loadLive(_ live: Live) async throws -> Live {
        try await load(live)
    }

    public func epg(for live: Live, channel: Channel? = nil) async throws -> [Epg] {
        try await loadEPG(for: live, channel: channel)
    }

    public func loadEPG(for live: Live) async throws -> [Epg] {
        try await loadEPG(for: live, channel: nil)
    }
}

public typealias URLSessionLiveRepository = DefaultLiveRepository

private extension DefaultLiveRepository {
    func inlineData(_ source: String) -> Data? {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = value.data(using: .utf8), !value.isEmpty else { return nil }
        let format = LivePlaylistParser.format(for: value)
        if format == .json && (value.hasPrefix("{") || value.hasPrefix("[")) { return data }
        if value.contains("#EXTM3U") || value.contains("#EXTINF") || value.contains(",#genre#") { return data }
        return nil
    }

    func requestHeaders(for live: Live) -> [String: String] {
        var headers = live.header
        if !live.userAgent.isEmpty { headers["User-Agent"] = live.userAgent }
        if !live.origin.isEmpty { headers["Origin"] = live.origin }
        if !live.referer.isEmpty { headers["Referer"] = live.referer }
        return headers
    }

    func read(_ source: String, headers: [String: String], timeout: TimeInterval) async throws -> (data: Data, sourceURL: URL?) {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw LiveRepositoryError.emptySource }
        if let localURL = localURL(for: value) {
            do {
                return (try Data(contentsOf: localURL), localURL)
            } catch {
                throw LiveRepositoryError.localReadFailed(error.localizedDescription)
            }
        }

        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            throw LiveRepositoryError.invalidURL(value)
        }
        guard scheme == "http" || scheme == "https" else {
            throw LiveRepositoryError.unsupportedScheme(scheme)
        }
        let response = try await client.send(HTTPRequest(url: url, headers: headers, timeout: timeout))
        return (response.data, response.url ?? url)
    }

    func localURL(for value: String) -> URL? {
        if value.lowercased().hasPrefix("file://"), let url = URL(string: value) { return url }
        let expanded = (value as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) { return URL(fileURLWithPath: expanded) }
        if !value.contains("://"), value.hasPrefix("/") { return URL(fileURLWithPath: value) }
        return nil
    }
}
