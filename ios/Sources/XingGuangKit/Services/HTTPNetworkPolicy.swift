import Foundation

public struct HTTPHeaderRule: Codable, Equatable {
    public var host: String
    public var header: [String: String]

    public init(host: String = "", header: [String: String] = [:]) {
        self.host = host
        self.header = header
    }
}

public struct DoHServer: Codable, Equatable, Identifiable {
    public var id: String { url }
    public var name: String
    public var url: String
    public var ips: [String]

    public init(name: String = "", url: String = "", ips: [String] = []) {
        self.name = name
        self.url = url
        self.ips = ips
    }
}

public final class HTTPNetworkPolicyStore: @unchecked Sendable {
    private let lock = NSLock()
    private var headerRules: [HTTPHeaderRule] = []
    private var blockedHosts: [String] = []
    private var dohServers: [DoHServer] = []

    public init() {}

    public func apply(_ configuration: VodConfigDocument) {
        lock.lock()
        headerRules = configuration.headers
        blockedHosts = configuration.ads.filter { !$0.isEmpty }
        dohServers = configuration.doh
        lock.unlock()
    }

    public func prepare(_ request: HTTPRequest) throws -> HTTPRequest {
        try validate(request.url)
        var prepared = request
        for rule in snapshot().headers where Self.matches(request.url.host ?? "", pattern: rule.host) {
            for (key, value) in rule.header {
                if let existing = prepared.headers.keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                    prepared.headers.removeValue(forKey: existing)
                }
                prepared.headers[key] = value
            }
        }
        return prepared
    }

    public func validate(_ url: URL) throws {
        guard !isBlocked(url) else {
            throw HTTPClientError.blocked(url.host ?? url.absoluteString)
        }
    }

    public func isBlocked(_ url: URL) -> Bool {
        let host = url.host ?? ""
        return snapshot().ads.contains { Self.matches(host, pattern: $0) }
    }

    public func configuredDoHServers() -> [DoHServer] {
        snapshot().doh
    }

    public func adPatterns() -> [String] {
        snapshot().ads
    }

    func webKitContentBlockerRules() -> String? {
        let rules: [[String: Any]] = adPatterns().map { pattern in
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
            return [
                "trigger": [
                    "url-filter": "^[a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]*\(escaped)[^/?#]*([/?#]|$)",
                    "url-filter-is-case-sensitive": false
                ],
                "action": ["type": "block"]
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rules) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func snapshot() -> (headers: [HTTPHeaderRule], ads: [String], doh: [DoHServer]) {
        lock.lock()
        defer { lock.unlock() }
        return (headerRules, blockedHosts, dohServers)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        if value.localizedCaseInsensitiveContains(pattern) { return true }
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = expression.firstMatch(in: value, range: range) else { return false }
        return match.range == range
    }
}

public enum HTTPRedirectPolicy {
    public static func targetURL(from response: HTTPURLResponse, originalURL: URL) -> URL? {
        guard (300..<400).contains(response.statusCode),
              let location = response.allHeaderFields.first(where: {
                  String(describing: $0.key).caseInsensitiveCompare("Location") == .orderedSame
              }).map({ String(describing: $0.value) }),
              !location.isEmpty else { return nil }
        return URL(string: location, relativeTo: response.url ?? originalURL)?.absoluteURL
    }
}
