import Foundation

public struct Live: Codable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var url: String
    public var api: String
    public var ext: JSONValue?
    public var jar: String
    public var click: String
    public var logo: String
    public var epg: String
    public var userAgent: String
    public var origin: String
    public var referer: String
    public var timeZone: String
    public var timeout: Int
    public var header: [String: String]
    public var catchup: Catchup?
    public var groups: [LiveGroup]
    public var boot: Bool
    public var pass: Bool

    enum CodingKeys: String, CodingKey {
        case name, url, api, ext, jar, click, logo, epg, origin, referer
        case timeZone, timeout, header, catchup, groups, boot, pass
        case userAgent = "ua"
    }

    public init(name: String = "", url: String = "", groups: [LiveGroup] = []) {
        self.name = name
        self.url = url
        self.api = ""
        self.ext = nil
        self.jar = ""
        self.click = ""
        self.logo = ""
        self.epg = ""
        self.userAgent = ""
        self.origin = ""
        self.referer = ""
        self.timeZone = ""
        self.timeout = 0
        self.header = [:]
        self.catchup = nil
        self.groups = groups
        self.boot = false
        self.pass = false
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.string(.name)
        url = container.string(.url)
        api = container.string(.api)
        ext = try? container.decodeIfPresent(JSONValue.self, forKey: .ext)
        jar = container.string(.jar)
        click = container.string(.click)
        logo = container.string(.logo)
        epg = container.string(.epg)
        userAgent = container.string(.userAgent)
        origin = container.string(.origin)
        referer = container.string(.referer)
        timeZone = container.string(.timeZone)
        timeout = container.integer(.timeout)
        header = container.dictionary(String.self, .header)
        catchup = try? container.decodeIfPresent(Catchup.self, forKey: .catchup)
        groups = container.array(LiveGroup.self, .groups)
        boot = container.boolean(.boot)
        pass = container.boolean(.pass)
    }
}

public struct LiveGroup: Codable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var pass: String
    public var channels: [Channel]

    enum CodingKeys: String, CodingKey {
        case name, pass
        case channels = "channel"
    }

    public init(name: String = "", pass: String = "", channels: [Channel] = []) {
        self.name = name
        self.pass = pass
        self.channels = channels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.string(.name)
        pass = container.string(.pass)
        channels = container.array(Channel.self, .channels)
    }
}

public struct Channel: Codable, Equatable, Identifiable {
    public var id: String { number.isEmpty ? name : number }
    public var urls: [String]
    public var number: String
    public var logo: String
    public var epg: String
    public var name: String
    public var userAgent: String
    public var click: String
    public var format: String
    public var origin: String
    public var referer: String
    public var tvgID: String
    public var tvgName: String
    public var header: [String: String]
    public var parse: Int
    public var catchup: Catchup?
    public var drm: PlaybackDRM?

    enum CodingKeys: String, CodingKey {
        case urls, number, logo, epg, name, click, format, origin, referer, header, parse
        case userAgent = "ua"
        case tvgID = "tvgId"
        case tvgName, catchup, drm
    }

    public init(name: String = "", number: String = "", urls: [String] = []) {
        self.urls = urls
        self.number = number
        self.logo = ""
        self.epg = ""
        self.name = name
        self.userAgent = ""
        self.click = ""
        self.format = ""
        self.origin = ""
        self.referer = ""
        self.tvgID = ""
        self.tvgName = ""
        self.header = [:]
        self.parse = 0
        self.catchup = nil
        self.drm = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urls = container.array(String.self, .urls)
        number = container.string(.number)
        logo = container.string(.logo)
        epg = container.string(.epg)
        name = container.string(.name)
        userAgent = container.string(.userAgent)
        click = container.string(.click)
        format = container.string(.format)
        origin = container.string(.origin)
        referer = container.string(.referer)
        tvgID = container.string(.tvgID)
        tvgName = container.string(.tvgName)
        header = container.dictionary(String.self, .header)
        parse = container.integer(.parse)
        catchup = try? container.decodeIfPresent(Catchup.self, forKey: .catchup)
        drm = try? container.decodeIfPresent(PlaybackDRM.self, forKey: .drm)
    }
}

public struct Epg: Codable, Equatable, Identifiable {
    public var id: String { key }
    public var key: String
    public var date: String
    public var list: [EpgData]

    enum CodingKeys: String, CodingKey {
        case key, date
        case list = "epg_data"
    }

    public init(key: String = "", date: String = "", list: [EpgData] = []) {
        self.key = key
        self.date = date
        self.list = list
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.string(.key)
        date = container.string(.date)
        list = container.array(EpgData.self, .list)
    }
}

public struct EpgData: Codable, Equatable, Identifiable {
    public var id: String { "\(start):\(title)" }
    public var title: String
    public var start: String
    public var end: String
    public var description: String
    public var startTime: Int64
    public var endTime: Int64

    enum CodingKeys: String, CodingKey {
        case title, start, end
        case description = "desc"
        case startTime, endTime
    }

    public init(
        title: String = "",
        start: String = "",
        end: String = "",
        description: String = "",
        startTime: Int64 = 0,
        endTime: Int64 = 0
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.string(.title)
        start = container.string(.start)
        end = container.string(.end)
        description = container.string(.description)
        startTime = container.int64(.startTime)
        endTime = container.int64(.endTime)
    }
}

/// Android's catch-up descriptor turns an EPG interval into a replay URL.
public struct Catchup: Codable, Equatable {
    public var type: String
    public var days: String
    public var regex: String
    public var source: String
    public var replace: String

    enum CodingKeys: String, CodingKey {
        case type, days, regex, source, replace
    }

    public init(
        type: String = "",
        days: String = "",
        regex: String = "",
        source: String = "",
        replace: String = ""
    ) {
        self.type = type
        self.days = days
        self.regex = regex
        self.source = source
        self.replace = replace
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.string(.type)
        days = container.string(.days)
        regex = container.string(.regex)
        source = container.string(.source)
        replace = container.string(.replace)
    }

    public var isEmpty: Bool { source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public static var pltv: Catchup {
        Catchup(
            type: "append",
            days: "7",
            regex: "/PLTV/",
            source: "?playseek=${(b)yyyyMMddHHmmss}-${(e)yyyyMMddHHmmss}",
            replace: "/PLTV/,/TVOD/"
        )
    }

    public func matches(_ url: String) -> Bool {
        guard !isEmpty else { return false }
        let pattern = regex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return true }
        if url.contains(pattern) { return true }
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(url.startIndex..<url.endIndex, in: url)
        return expression.firstMatch(in: url, range: range) != nil
    }

    /// Returns nil when the channel does not match or the programme is outside
    /// the configured replay window. A malformed template falls back to nil.
    public func replayURL(
        baseURL: String,
        programme: EpgData,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String? {
        guard !isEmpty, matches(baseURL) else { return nil }
        let start = programme.startTime
        let end = programme.endTime
        if let limit = Int(days), limit > 0, start > 0 {
            let age = now.timeIntervalSince1970 - Double(start) / 1000
            if age > Double(limit) * 86_400 { return nil }
        }

        var rendered = source
        let pattern = #"\$?\{([^}]+)\}"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = expression.matches(in: rendered, range: NSRange(rendered.startIndex..<rendered.endIndex, in: rendered))
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let tokenRange = Range(match.range(at: 1), in: rendered) else { return nil }
            let token = String(rendered[tokenRange])
            let replacement: String
            if token.hasPrefix("(b)") {
                replacement = formatDate(Double(start) / 1000, pattern: String(token.dropFirst(3)), timeZone: timeZone)
            } else if token.hasPrefix("(e)") {
                replacement = formatDate(Double(end) / 1000, pattern: String(token.dropFirst(3)), timeZone: timeZone)
            } else if token == "utc" {
                replacement = String(max(start, 0) / 1000)
            } else if token == "utcend" {
                replacement = String(max(end, 0) / 1000)
            } else {
                return nil
            }
            guard !replacement.isEmpty else { return nil }
            guard let fullRange = Range(match.range, in: rendered) else { return nil }
            rendered.replaceSubrange(fullRange, with: replacement)
        }

        if type.lowercased() == "default" { return rendered }
        var url = baseURL
        if !replace.isEmpty {
            let parts = replace.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let pattern = String(parts[0])
                let replacement = String(parts[1])
                if let expression = try? NSRegularExpression(pattern: pattern) {
                    url = expression.stringByReplacingMatches(
                        in: url,
                        range: NSRange(url.startIndex..<url.endIndex, in: url),
                        withTemplate: replacement
                    )
                } else {
                    url = url.replacingOccurrences(of: pattern, with: replacement)
                }
            }
        }
        let separator = url.contains("?") ? "&" : "?"
        return url + (rendered.hasPrefix("?") || rendered.hasPrefix("&") ? rendered : separator + rendered)
    }

    private func formatDate(_ seconds: Double, pattern: String, timeZone: TimeZone) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }
}
