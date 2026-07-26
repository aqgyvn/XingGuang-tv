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
        guard !isBlocked(request.url) else {
            throw HTTPClientError.blocked(request.url.host ?? request.url.absoluteString)
        }
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
