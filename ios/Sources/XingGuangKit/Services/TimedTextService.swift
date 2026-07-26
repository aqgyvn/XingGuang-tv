import Foundation

public enum TimedTextError: Error, Equatable, LocalizedError {
    case invalidURL
    case unreadableText
    case unsupportedFormat(String)
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "字幕或弹幕地址无效"
        case .unreadableText: return "字幕或弹幕文本无法读取"
        case .unsupportedFormat(let format): return "不支持的字幕或弹幕格式：\(format)"
        case .emptyResult: return "字幕或弹幕内容为空"
        }
    }
}

public struct TimedTextCue: Equatable, Identifiable {
    public var id: Int
    public var start: TimeInterval
    public var end: TimeInterval
    public var text: String

    public init(id: Int, start: TimeInterval, end: TimeInterval, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

public struct DanmakuCue: Equatable, Identifiable {
    public enum Placement: Equatable {
        case scrolling
        case top
        case bottom
    }

    public var id: Int
    public var start: TimeInterval
    public var duration: TimeInterval
    public var text: String
    public var color: UInt32
    public var fontSize: Double
    public var placement: Placement

    public init(
        id: Int,
        start: TimeInterval,
        duration: TimeInterval = 8,
        text: String,
        color: UInt32 = 0xFFFFFF,
        fontSize: Double = 24,
        placement: Placement = .scrolling
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.placement = placement
    }
}

public enum TimedTextParser {
    public static func subtitles(data: Data, format: String = "", url: String = "") throws -> [TimedTextCue] {
        guard let text = decode(data) else { throw TimedTextError.unreadableText }
        let normalizedFormat = inferredFormat(format: format, url: url)
        let cues: [TimedTextCue]
        switch normalizedFormat {
        case "srt", "vtt", "webvtt", "text/vtt", "application/x-subrip", "":
            cues = parseArrowTimedText(text)
        case "ass", "ssa", "text/x-ssa", "text/x-ass":
            cues = parseASS(text)
        default:
            throw TimedTextError.unsupportedFormat(normalizedFormat)
        }
        guard !cues.isEmpty else { throw TimedTextError.emptyResult }
        return cues
    }

    public static func danmaku(data: Data, format: String = "", url: String = "") throws -> [DanmakuCue] {
        guard let text = decode(data) else { throw TimedTextError.unreadableText }
        let normalizedFormat = inferredFormat(format: format, url: url)
        let cues: [DanmakuCue]
        if normalizedFormat == "xml" || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
            cues = parseDanmakuXML(data, fallbackText: text)
        } else {
            cues = parseDanmakuText(text)
        }
        guard !cues.isEmpty else { throw TimedTextError.emptyResult }
        return cues
    }

    private static func decode(_ data: Data) -> String? {
        if let value = String(data: data, encoding: .utf8) { return value }
        if let value = String(data: data, encoding: .utf16) { return value }
        if let value = String(data: data, encoding: .utf16LittleEndian) { return value }
        if let value = String(data: data, encoding: .utf16BigEndian) { return value }
        return String(data: data, encoding: .isoLatin1)
    }

    private static func inferredFormat(format: String, url: String) -> String {
        let value = format.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !value.isEmpty { return value }
        return URL(string: url)?.pathExtension.lowercased() ?? ""
    }

    private static func parseArrowTimedText(_ text: String) -> [TimedTextCue] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [TimedTextCue] = []
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timing = lines[timingIndex].components(separatedBy: "-->")
            guard timing.count == 2,
                  let start = parseClock(timing[0]),
                  let end = parseClock(timing[1].split(separator: " ").first.map(String.init) ?? timing[1]) else { continue }
            let body = lines.dropFirst(timingIndex + 1).joined(separator: "\n")
            let value = cleanMarkup(body)
            guard !value.isEmpty, end >= start else { continue }
            cues.append(TimedTextCue(id: cues.count, start: start, end: end, text: value))
        }
        return cues
    }

    private static func parseASS(_ text: String) -> [TimedTextCue] {
        var cues: [TimedTextCue] = []
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("Dialogue:") {
            let payload = line.dropFirst("Dialogue:".count)
            let fields = payload.split(separator: ",", maxSplits: 9, omittingEmptySubsequences: false)
            guard fields.count == 10,
                  let start = parseClock(String(fields[1])),
                  let end = parseClock(String(fields[2])) else { continue }
            let value = cleanMarkup(String(fields[9]).replacingOccurrences(of: "\\N", with: "\n"))
            guard !value.isEmpty, end >= start else { continue }
            cues.append(TimedTextCue(id: cues.count, start: start, end: end, text: value))
        }
        return cues
    }

    private static func parseDanmakuXML(_ data: Data, fallbackText: String) -> [DanmakuCue] {
        let delegate = DanmakuXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        if parser.parse(), !delegate.cues.isEmpty { return delegate.cues }

        let pattern = #"<d[^>]*p="([^"]+)"[^>]*>(.*?)</d>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(fallbackText.startIndex..., in: fallbackText)
        return expression.matches(in: fallbackText, range: range).enumerated().compactMap { index, match in
            guard let parameterRange = Range(match.range(at: 1), in: fallbackText),
                  let textRange = Range(match.range(at: 2), in: fallbackText) else { return nil }
            return danmakuCue(parameters: String(fallbackText[parameterRange]), text: String(fallbackText[textRange]), id: index)
        }
    }

    private static func parseDanmakuText(_ text: String) -> [DanmakuCue] {
        let pattern = #"\[(.*?)\](.*)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        var cues: [DanmakuCue] = []
        for line in text.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = expression.firstMatch(in: line, range: range),
                  let timeRange = Range(match.range(at: 1), in: line),
                  let textRange = Range(match.range(at: 2), in: line),
                  let start = parseClock(String(line[timeRange])) else { continue }
            let value = cleanMarkup(String(line[textRange]))
            guard !value.isEmpty else { continue }
            cues.append(DanmakuCue(id: cues.count, start: start, text: value))
        }
        return cues
    }

    fileprivate static func danmakuCue(parameters: String, text: String, id: Int) -> DanmakuCue? {
        let values = parameters.components(separatedBy: ",")
        guard values.count >= 4, let start = TimeInterval(values[0]) else { return nil }
        let type = Int(values[1]) ?? 1
        let size = Double(values[2]) ?? 24
        let color = UInt32(values[3]) ?? 0xFFFFFF
        let placement: DanmakuCue.Placement
        switch type {
        case 4: placement = .bottom
        case 5: placement = .top
        default: placement = .scrolling
        }
        let value = cleanMarkup(text)
        guard !value.isEmpty else { return nil }
        return DanmakuCue(
            id: id,
            start: start,
            duration: placement == .scrolling ? 8 : 4,
            text: value,
            color: color,
            fontSize: size,
            placement: placement
        )
    }

    private static func parseClock(_ value: String) -> TimeInterval? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.components(separatedBy: ":")
        if parts.count == 1 { return TimeInterval(parts[0]) }
        guard parts.count <= 3 else { return nil }
        var total: TimeInterval = 0
        for part in parts {
            guard let number = TimeInterval(part) else { return nil }
            total = total * 60 + number
        }
        return total
    }

    private static func cleanMarkup(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
        for pattern in [#"<[^>]+>"#, #"\{[^}]*\}"#] {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public protocol TimedTextLoading: Sendable {
    func loadSubtitle(_ resource: SubtitleResource, headers: [String: String], cookies: [String: String]) async throws -> [TimedTextCue]
    func loadDanmaku(_ resource: DanmakuResource, headers: [String: String], cookies: [String: String]) async throws -> [DanmakuCue]
}

public final class TimedTextLoader: TimedTextLoading, @unchecked Sendable {
    private let client: HTTPClient

    public init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    public func loadSubtitle(_ resource: SubtitleResource, headers: [String: String] = [:], cookies: [String: String] = [:]) async throws -> [TimedTextCue] {
        let data = try await fetch(resource.url, headers: headers, cookies: cookies)
        return try TimedTextParser.subtitles(data: data, format: resource.format, url: resource.url)
    }

    public func loadDanmaku(_ resource: DanmakuResource, headers: [String: String] = [:], cookies: [String: String] = [:]) async throws -> [DanmakuCue] {
        let data = try await fetch(resource.url, headers: headers, cookies: cookies)
        return try TimedTextParser.danmaku(data: data, format: resource.format, url: resource.url)
    }

    private func fetch(_ value: String, headers: [String: String], cookies: [String: String]) async throws -> Data {
        guard let url = URL(string: value) else { throw TimedTextError.invalidURL }
        if url.isFileURL { return try Data(contentsOf: url) }
        return try await client.send(HTTPRequest(url: url, headers: headers, cookies: cookies)).data
    }
}

private final class DanmakuXMLDelegate: NSObject, XMLParserDelegate {
    private var parameters = ""
    private var text = ""
    private var reading = false
    fileprivate var cues: [DanmakuCue] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "d", let value = attributeDict["p"] else { return }
        parameters = value
        text = ""
        reading = true
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if reading { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "d", reading else { return }
        if let cue = TimedTextParser.danmakuCue(parameters: parameters, text: text, id: cues.count) {
            cues.append(cue)
        }
        reading = false
    }
}
