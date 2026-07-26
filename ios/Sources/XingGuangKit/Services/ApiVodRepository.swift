import Foundation

public enum VodRepositoryError: Error, Equatable, LocalizedError {
    case invalidSite
    case unsupportedSiteType(Int)
    case invalidResponse
    case unsupportedPlayback(String)
    case unsupportedDependency(String)
    case drmUnsupported(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSite: return "点播来源配置无效"
        case .unsupportedSiteType(let type): return "iOS 暂不支持此来源类型（\(type)）"
        case .invalidResponse: return "点播来源返回的数据无效"
        case .unsupportedPlayback(let value): return value
        case .unsupportedDependency(let value): return "iOS 暂不支持此来源依赖：\(value)"
        case .drmUnsupported(let value): return "此视频使用 iOS 不支持的 DRM：\(value)"
        }
    }
}

public final class ApiVodRepository: VodRepository, @unchecked Sendable {
    private let client: HTTPClient
    private let decoder: JSONDecoder

    public init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
        self.decoder = JSONDecoder()
    }

    public func loadConfig(from url: URL) async throws -> VodConfigDocument {
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            data = try await client.send(HTTPRequest(url: url)).data
        }
        return try decoder.decode(VodConfigDocument.self, from: data)
    }

    public func home(site: Site, includeFilters: Bool = true) async throws -> VodResult {
        try await request(site: site, params: site.type == 4 ? ["filter": includeFilters ? "true" : "false"] : [:], xmlAllowed: true)
    }

    public func category(site: Site, typeID: String, page: Int = 1, filters: [String: String] = [:]) async throws -> VodResult {
        var params: [String: String] = [
            "ac": site.type == 0 ? "videolist" : "detail",
            "t": typeID,
            "pg": String(max(page, 1))
        ]
        if site.type == 1, !filters.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: filters)
            params["f"] = String(data: data, encoding: .utf8) ?? "{}"
        }
        if site.type == 4 {
            let data = try JSONSerialization.data(withJSONObject: filters)
            params["ext"] = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return try await request(site: site, params: params, xmlAllowed: site.type == 0)
    }

    public func search(site: Site, keyword: String, page: Int = 1) async throws -> VodResult {
        var params = ["wd": keyword, "quick": "false", "extend": ""]
        if page > 1 { params["pg"] = String(page) }
        return try await request(site: site, params: params, xmlAllowed: site.type == 0)
    }

    public func detail(site: Site, vodID: String) async throws -> VodResult {
        let params = ["ac": site.type == 0 ? "videolist" : "detail", "ids": vodID]
        return try await request(site: site, params: params, xmlAllowed: site.type == 0)
    }

    public func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        guard !episodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VodRepositoryError.unsupportedPlayback("选集播放地址为空")
        }
        guard let url = URL(string: episodeURL), url.scheme != nil else {
            throw VodRepositoryError.unsupportedPlayback("播放地址不是有效 URL")
        }
        if site.type == 4 {
            let result = try await request(site: site, params: ["play": episodeURL, "flag": flag], xmlAllowed: false)
            var headers = site.header
            headers.merge(result.header) { _, new in new }
            if let resolved = result.list.first?.vodPlayURL.components(separatedBy: "$$$").first, !resolved.isEmpty {
                return playbackRequest(url: resolved, headers: headers, result: result, site: site)
            }
            if !result.url.isEmpty { return playbackRequest(url: result.url, headers: headers, result: result, site: site) }
        }
        if site.type == 3 {
            throw VodRepositoryError.unsupportedPlayback("JavaScript 来源将在下一阶段接入")
        }
        return PlaybackRequest(
            url: episodeURL,
            headers: site.header,
            timeout: TimeInterval(site.timeout > 0 ? site.timeout : 15)
        )
    }

    private func request(site: Site, params: [String: String], xmlAllowed: Bool) async throws -> VodResult {
        guard !site.api.isEmpty, let baseURL = URL(string: site.api) else { throw VodRepositoryError.invalidSite }
        guard site.type == 0 || site.type == 1 || site.type == 4 else { throw VodRepositoryError.unsupportedSiteType(site.type) }
        var requestURL = baseURL
        var request = HTTPRequest(url: baseURL, headers: site.header, timeout: TimeInterval(site.timeout > 0 ? site.timeout : 15))
        var body: Data?
        var requestParams = params
        let ext = try await resolvedExtension(site.extString, headers: site.header)
        if !ext.isEmpty { requestParams["extend"] = ext }
        if !requestParams.isEmpty {
            if ext.count <= 1000 {
                guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                    throw VodRepositoryError.invalidSite
                }
                components.queryItems = (components.queryItems ?? []) + requestParams.map { URLQueryItem(name: $0.key, value: $0.value) }
                guard let url = components.url else { throw VodRepositoryError.invalidSite }
                requestURL = url
            } else {
                body = requestParams.map { "\(urlEncode($0.key))=\(urlEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
                request.method = .post
                request.headers["Content-Type"] = "application/x-www-form-urlencoded"
            }
        }
        request.url = requestURL
        request.body = body
        let response = try await client.send(request)
        guard !response.data.isEmpty else { throw HTTPClientError.emptyResponse }
        if site.type == 0 && xmlAllowed {
            return try VodXMLParser.parse(response.data)
        }
        do {
            return try decoder.decode(VodResult.self, from: response.data)
        } catch {
            throw VodRepositoryError.invalidResponse
        }
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func resolvedExtension(_ value: String, headers: [String: String]) async throws -> String {
        guard let url = URL(string: value), url.scheme == "http" || url.scheme == "https" else { return value }
        return String(data: try await client.send(HTTPRequest(url: url, headers: headers)).data, encoding: .utf8) ?? ""
    }

    private func playbackRequest(url: String, headers: [String: String], result: VodResult, site: Site) -> PlaybackRequest {
        PlaybackRequest(
            url: url,
            headers: headers,
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
}

private extension Site {
    var extString: String { ext?.stringValue ?? "" }
}
