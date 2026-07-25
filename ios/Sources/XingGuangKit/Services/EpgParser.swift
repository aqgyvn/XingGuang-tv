import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

public enum EpgParserError: Error, Equatable, LocalizedError {
    case emptySource
    case invalidJSON
    case invalidXML
    case unsupportedFormat
    case gzipUnsupported
    case gzipDecompressionFailed

    public var errorDescription: String? {
        switch self {
        case .emptySource: return "The EPG source is empty."
        case .invalidJSON: return "The EPG JSON is invalid."
        case .invalidXML: return "The EPG XML is invalid."
        case .unsupportedFormat: return "The EPG format is not supported."
        case .gzipUnsupported: return "Gzip-compressed EPG is not supported on this build."
        case .gzipDecompressionFailed: return "The gzip-compressed EPG could not be decompressed."
        }
    }
}

/// Parses the JSON Epg model and XMLTV feeds used by the Android client.
public struct EpgParser {
    public init() {}

    public static func parse(_ data: Data, channelKeys: Set<String>? = nil) throws -> [Epg] {
        guard !data.isEmpty else { throw EpgParserError.emptySource }
        let payload: Data
        if data.count >= 2 && data[data.startIndex] == 0x1f && data[data.index(after: data.startIndex)] == 0x8b {
            do {
                payload = try SystemGzipDecompressor().decompress(data)
            } catch {
                throw EpgParserError.gzipDecompressionFailed
            }
        } else {
            payload = data
        }
        let first = String(data: payload.prefix(256), encoding: .utf8)?
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if first.hasPrefix("{") || first.hasPrefix("[") {
            return try parseJSON(payload)
        }
        if first.hasPrefix("<") {
            return try parseXML(payload, channelKeys: channelKeys)
        }
        throw EpgParserError.unsupportedFormat
    }

    public static func parseJSON(_ data: Data) throws -> [Epg] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw EpgParserError.invalidJSON
        }
        let parsed = parseJSONValue(object, fallbackKey: "")
        if parsed.isEmpty, !(object is [Any]) { throw EpgParserError.invalidJSON }
        return parsed
    }

    public static func parseXML(_ data: Data, channelKeys: Set<String>? = nil) throws -> [Epg] {
        let delegate = XMLTVDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), delegate.error == nil else { throw EpgParserError.invalidXML }

        var grouped: [String: [String: [EpgData]]] = [:]
        for programme in delegate.programmes {
            let key = programme.channel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let aliases = delegate.channelAliases[key] ?? []
            if let channelKeys = channelKeys, !channelKeys.isEmpty,
               !channelKeys.contains(key), aliases.isDisjoint(with: channelKeys) { continue }
            let outputKey = channelKeys?.first(where: { $0 == key || aliases.contains($0) }) ?? key
            let startDate = parseXMLDate(programme.start)
            let endDate = parseXMLDate(programme.stop)
            let date = startDate.map(formatDate) ?? datePart(programme.start)
            let start = startDate.map(formatTime) ?? timePart(programme.start)
            let end = endDate.map(formatTime) ?? timePart(programme.stop)
            let item = EpgData(
                title: programme.title.trimmingCharacters(in: .whitespacesAndNewlines),
                start: start,
                end: end,
                description: programme.description.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: startDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0,
                endTime: endDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0
            )
            var dates = grouped[outputKey] ?? [:]
            dates[date, default: []].append(item)
            grouped[outputKey] = dates
        }

        return grouped.keys.sorted().flatMap { key in
            grouped[key, default: [:]].keys.sorted().map { date in
                Epg(key: key, date: date, list: grouped[key]?[date] ?? [])
            }
        }
    }
}

private extension EpgParser {
    static func parseJSONValue(_ value: Any, fallbackKey: String) -> [Epg] {
        if let array = value as? [Any] {
            var direct: [Epg] = []
            var dataItems: [EpgData] = []
            for item in array {
                if let dictionary = item as? [String: Any] {
                    if let epg = parseEpgObject(dictionary, fallbackKey: fallbackKey) {
                        direct.append(epg)
                    } else if let epgData = parseEpgData(dictionary) {
                        dataItems.append(epgData)
                    }
                }
            }
            if !dataItems.isEmpty {
                direct.append(Epg(key: fallbackKey, date: dateFromData(dataItems), list: dataItems))
            }
            return direct
        }

        guard let dictionary = value as? [String: Any] else { return [] }
        if let epg = parseEpgObject(dictionary, fallbackKey: fallbackKey) { return [epg] }
        if let nested = dictionary["epg"] ?? dictionary["data"] ?? dictionary["list"] {
            return parseJSONValue(nested, fallbackKey: string(dictionary["key"] ?? dictionary["id"] ?? fallbackKey))
        }

        var result: [Epg] = []
        for (key, value) in dictionary {
            guard let array = value as? [Any] else { continue }
            let items = array.compactMap { $0 as? [String: Any] }.compactMap(parseEpgData)
            if !items.isEmpty {
                result.append(Epg(key: key, date: dateFromData(items), list: items))
            }
        }
        return result
    }

    static func parseEpgObject(_ dictionary: [String: Any], fallbackKey: String) -> Epg? {
        let listValue = dictionary["epg_data"] ?? dictionary["list"] ?? dictionary["programmes"] ?? dictionary["programs"]
        guard let list = listValue as? [Any] else { return nil }
        let items = list.compactMap { $0 as? [String: Any] }.compactMap(parseEpgData)
        let key = string(dictionary["key"] ?? dictionary["id"] ?? dictionary["channel"] ?? dictionary["tvgId"] ?? fallbackKey)
        let date = string(dictionary["date"] ?? "")
        return Epg(key: key, date: date.isEmpty ? dateFromData(items) : date, list: items)
    }

    static func parseEpgData(_ dictionary: [String: Any]) -> EpgData? {
        let title = string(dictionary["title"] ?? dictionary["name"] ?? "")
        let start = string(dictionary["start"] ?? dictionary["startTime"] ?? "")
        let end = string(dictionary["end"] ?? dictionary["endTime"] ?? "")
        let description = string(dictionary["desc"] ?? dictionary["description"] ?? "")
        guard !title.isEmpty || !start.isEmpty || !end.isEmpty else { return nil }
        return EpgData(
            title: title,
            start: start,
            end: end,
            description: description,
            startTime: integer64(dictionary["startTime"] ?? dictionary["start_time"] ?? 0),
            endTime: integer64(dictionary["endTime"] ?? dictionary["end_time"] ?? 0)
        )
    }

    static func string(_ value: Any) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    static func integer64(_ value: Any) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) ?? 0 }
        return 0
    }

    static func dateFromData(_ items: [EpgData]) -> String {
        guard let value = items.first?.start else { return "" }
        if value.count >= 10, value[value.index(value.startIndex, offsetBy: 4)] == "-" {
            return String(value.prefix(10))
        }
        return ""
    }

    static func parseXMLDate(_ value: String) -> Date? {
        let formats = [
            "yyyyMMddHHmmss Z",
            "yyyyMMddHHmmss.SSS Z",
            "yyyyMMddHHmmssZ",
            "yyyyMMddHHmmss.SSSZ",
            "yyyyMMddHHmmss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if !format.contains("Z") && !format.contains("X") { formatter.timeZone = TimeZone.current }
            if let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) { return date }
        }
        return nil
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func datePart(_ value: String) -> String {
        let digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard digits.count >= 8 else { return "" }
        let raw = String(digits.prefix(8))
        guard raw.allSatisfy({ $0.isNumber }) else { return "" }
        return "\(raw.prefix(4))-\(raw.dropFirst(4).prefix(2))-\(raw.dropFirst(6).prefix(2))"
    }

    static func timePart(_ value: String) -> String {
        let digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard digits.count >= 12 else { return "" }
        let raw = String(digits.dropFirst(8).prefix(6))
        guard raw.allSatisfy({ $0.isNumber }) else { return "" }
        return "\(raw.prefix(2)):\(raw.dropFirst(2).prefix(2))"
    }
}

private struct XMLProgramme {
    var channel: String
    var start: String
    var stop: String
    var title = ""
    var description = ""
}

private final class XMLTVDelegate: NSObject, XMLParserDelegate {
    var programmes: [XMLProgramme] = []
    var channelAliases: [String: Set<String>] = [:]
    var error: Error?
    private var current: XMLProgramme?
    private var currentChannelID: String?
    private var text = ""

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        error = validationError
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let element = elementName.lowercased()
        text = ""
        if element == "programme" {
            current = XMLProgramme(
                channel: attributeDict["channel"] ?? "",
                start: attributeDict["start"] ?? "",
                stop: attributeDict["stop"] ?? ""
            )
        } else if element == "channel" {
            currentChannelID = attributeDict["id"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "title", var item = current {
            item.title += text
            current = item
        }
        if (name == "desc" || name == "description"), var item = current {
            item.description += text
            current = item
        }
        if name == "display-name", let channelID = currentChannelID {
            let alias = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !alias.isEmpty { channelAliases[channelID, default: []].insert(alias) }
        }
        if name == "channel" { currentChannelID = nil }
        if name == "programme", let current {
            programmes.append(current)
            self.current = nil
        }
        text = ""
    }
}
