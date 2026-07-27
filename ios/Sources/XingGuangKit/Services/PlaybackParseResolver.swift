import Foundation

public protocol PlaybackParseResolving: Sendable {
    func resolve(
        result: VodResult,
        site: Site,
        context: VodPlaybackContext,
        originalURL: String,
        flag: String,
        inferParsingForUnknownURL: Bool
    ) async throws -> PlaybackRequest
}

public final class PlaybackParseResolver: PlaybackParseResolving, @unchecked Sendable {
    private let client: HTTPClient
    private let decoder = JSONDecoder()

    public init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    public func resolve(
        result: VodResult,
        site: Site,
        context: VodPlaybackContext,
        originalURL: String,
        flag: String,
        inferParsingForUnknownURL: Bool = false
    ) async throws -> PlaybackRequest {
        let sourceURL = result.url.isEmpty ? originalURL : result.url
        guard isValidURL(sourceURL) else {
            throw VodRepositoryError.unsupportedPlayback("播放地址不是有效 URL")
        }
        let headers = site.header.merging(result.header) { _, new in new }
        let effectiveFlag = result.jxFrom.isEmpty ? (result.flag.isEmpty ? flag : result.flag) : result.jxFrom
        let directive = result.playURL.isEmpty ? site.playURL : result.playURL
        let needsParsing = !directive.isEmpty
            || result.parse == 1
            || result.jx == 1
            || (inferParsingForUnknownURL && !isDirectMediaURL(sourceURL, format: result.format))

        guard needsParsing else {
            return makeRequest(url: sourceURL, headers: headers, result: result, site: site)
        }
        let rule = try selectedRule(directive: directive, parses: context.parses)
        return try await apply(
            rule: rule,
            sourceURL: sourceURL,
            headers: headers,
            result: result,
            site: site,
            parses: context.parses,
            flag: effectiveFlag
        )
    }

    private func selectedRule(directive: String, parses: [ParseRule]) throws -> ParseRule {
        if directive.hasPrefix("json:") {
            return ParseRule(type: 1, url: String(directive.dropFirst(5)))
        }
        if directive.hasPrefix("parse:") {
            let name = String(directive.dropFirst(6))
            guard let rule = parses.first(where: { $0.name == name }) else {
                throw VodRepositoryError.unsupportedPlayback("未找到指定解析器：\(name)")
            }
            return rule
        }
        if !directive.isEmpty { return ParseRule(type: 0, url: directive) }
        return ParseRule(name: "聚合解析", type: 4)
    }

    private func apply(
        rule: ParseRule,
        sourceURL: String,
        headers: [String: String],
        result: VodResult,
        site: Site,
        parses: [ParseRule],
        flag: String
    ) async throws -> PlaybackRequest {
        let parserHeaders = headers.merging(rule.ext?.header ?? [:]) { _, new in new }
        switch rule.type {
        case 0:
            return makeRequest(
                url: rule.url + sourceURL,
                headers: parserHeaders,
                result: result,
                site: site,
                requiresSniffing: true
            )
        case 1:
            return try await resolveJSON(rule: rule, sourceURL: sourceURL, headers: parserHeaders, result: result, site: site)
        case 2, 3:
            throw VodRepositoryError.unsupportedDependency("解析器 \(rule.name.isEmpty ? String(rule.type) : rule.name) 依赖 Android 扩展运行时")
        case 4:
            return try await resolveAggregate(sourceURL: sourceURL, headers: headers, result: result, site: site, parses: parses, flag: flag)
        default:
            throw VodRepositoryError.unsupportedPlayback("不支持的解析器类型：\(rule.type)")
        }
    }

    private func resolveJSON(
        rule: ParseRule,
        sourceURL: String,
        headers: [String: String],
        result: VodResult,
        site: Site
    ) async throws -> PlaybackRequest {
        guard let url = URL(string: rule.url + sourceURL), url.scheme != nil else {
            throw VodRepositoryError.unsupportedPlayback("JSON 解析器地址无效")
        }
        let response = try await client.send(HTTPRequest(url: url, headers: headers, timeout: timeout(for: site)))
        let parsed: JSONParseResponse
        do {
            parsed = try decoder.decode(JSONParseResponse.self, from: response.data)
        } catch {
            throw VodRepositoryError.invalidResponse
        }
        let resolvedURL = parsed.url.isEmpty ? parsed.data?.url ?? "" : parsed.url
        guard isValidURL(resolvedURL) else { throw VodRepositoryError.invalidResponse }
        let responseHeaders = allowedPlaybackHeaders(parsed.header.merging(parsed.rootHeaders) { _, new in new })
        return makeRequest(
            url: resolvedURL,
            headers: headers.merging(responseHeaders) { _, new in new },
            result: result,
            site: site
        )
    }

    private func resolveAggregate(
        sourceURL: String,
        headers: [String: String],
        result: VodResult,
        site: Site,
        parses: [ParseRule],
        flag: String
    ) async throws -> PlaybackRequest {
        let matched = parses.filter { $0.ext?.flag.contains(flag) == true }
        let candidates = matched.isEmpty ? parses : matched
        for rule in candidates where rule.type == 1 {
            do {
                return try await resolveJSON(
                    rule: rule,
                    sourceURL: sourceURL,
                    headers: headers.merging(rule.ext?.header ?? [:]) { _, new in new },
                    result: result,
                    site: site
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        if let web = candidates.first(where: { $0.type == 0 }) {
            return try await apply(rule: web, sourceURL: sourceURL, headers: headers, result: result, site: site, parses: [], flag: flag)
        }
        return makeRequest(url: sourceURL, headers: headers, result: result, site: site, requiresSniffing: true)
    }

    private func makeRequest(
        url: String,
        headers: [String: String],
        result: VodResult,
        site: Site,
        requiresSniffing: Bool = false
    ) -> PlaybackRequest {
        PlaybackRequest(
            url: url,
            headers: headers,
            format: result.format,
            artwork: result.artwork,
            subtitles: result.subtitles,
            danmaku: result.danmaku,
            drm: result.drm,
            timeout: timeout(for: site),
            requiresSniffing: requiresSniffing,
            sniffScript: result.click.isEmpty ? site.click : result.click
        )
    }

    private func allowedPlaybackHeaders(_ headers: [String: String]) -> [String: String] {
        let allowed = ["user-agent", "referer", "cookie"]
        return headers.reduce(into: [String: String]()) { result, item in
            let key = item.key.lowercased() == "ua" ? "user-agent" : item.key.lowercased()
            guard allowed.contains(key) else { return }
            switch key {
            case "user-agent": result["User-Agent"] = item.value
            case "referer": result["Referer"] = item.value
            case "cookie": result["Cookie"] = item.value
            default: break
            }
        }
    }

    private func isValidURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme else { return false }
        return !scheme.isEmpty
    }

    private func isDirectMediaURL(_ value: String, format: String) -> Bool {
        if !format.isEmpty { return true }
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("rtmp:") || lowercased.hasPrefix("rtsp:") || lowercased.hasPrefix("magnet:") || lowercased.hasPrefix("ed2k:") {
            return true
        }
        if lowercased.contains("url=http") || lowercased.contains("v=http") || lowercased.contains(".html") {
            return false
        }
        return [".m3u8", ".mp4", ".mkv", ".flv", ".mp3", ".m4a", ".aac", ".mpd", ".mov", ".webm"]
            .contains { lowercased.range(of: $0, options: .caseInsensitive) != nil }
    }

    private func timeout(for site: Site) -> TimeInterval {
        TimeInterval(site.timeout > 0 ? site.timeout : 15)
    }
}

private struct JSONParseResponse: Decodable {
    var url: String
    var header: [String: String]
    var rootHeaders: [String: String]
    var data: JSONParseData?

    enum CodingKeys: String, CodingKey { case url, header, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.string(.url)
        header = container.dictionary(String.self, .header)
        data = try? container.decodeIfPresent(JSONParseData.self, forKey: .data)
        let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
        rootHeaders = dynamic.allKeys.reduce(into: [String: String]()) { result, key in
            let normalized = key.stringValue.lowercased()
            guard normalized == "user-agent" || normalized == "referer" || normalized == "cookie" || normalized == "ua" else { return }
            if let value = try? dynamic.decode(String.self, forKey: key) { result[key.stringValue] = value }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private struct JSONParseData: Decodable {
    var url: String

    enum CodingKeys: String, CodingKey { case url }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.string(.url)
    }
}
