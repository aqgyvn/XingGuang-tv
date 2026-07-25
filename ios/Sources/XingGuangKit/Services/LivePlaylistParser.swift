import Foundation

/// The wire formats used by the Android live-list loader.
public enum LivePlaylistFormat: String, Equatable {
    case json
    case m3u
    case txt
}

public enum LivePlaylistParserError: Error, Equatable, LocalizedError {
    case emptyPlaylist
    case invalidUTF8
    case invalidJSON
    case invalidPlaylist

    public var errorDescription: String? {
        switch self {
        case .emptyPlaylist: return "The live playlist is empty."
        case .invalidUTF8: return "The live playlist is not valid UTF-8."
        case .invalidJSON: return "The live playlist JSON is invalid."
        case .invalidPlaylist: return "The live playlist contains no usable channels."
        }
    }
}

/// Parses the JSON, M3U and plain-text formats accepted by Android's LiveParser.
public struct LivePlaylistParser {
    public init() {}

    public func parse(_ data: Data, into live: Live = Live(), sourceURL: URL? = nil) throws -> Live {
        guard !data.isEmpty else { throw LivePlaylistParserError.emptyPlaylist }
        guard let text = String(data: data, encoding: .utf8) else {
            throw LivePlaylistParserError.invalidUTF8
        }
        return try parse(text, into: live, sourceURL: sourceURL)
    }

    public func parse(_ text: String, into live: Live = Live(), sourceURL: URL? = nil) throws -> Live {
        let normalized = text.replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw LivePlaylistParserError.emptyPlaylist }

        var result: Live
        switch Self.format(for: normalized, sourceURL: sourceURL) {
        case .json:
            result = try Self.parseJSON(normalized, into: live)
        case .m3u:
            result = Self.parseM3U(normalized, into: live)
        case .txt:
            result = Self.parseTXT(normalized, into: live)
        }
        return Self.applyingDefaults(result)
    }

    public static func parse(_ data: Data, into live: Live = Live(), sourceURL: URL? = nil) throws -> Live {
        try LivePlaylistParser().parse(data, into: live, sourceURL: sourceURL)
    }

    public static func parse(_ text: String, into live: Live = Live(), sourceURL: URL? = nil) throws -> Live {
        try LivePlaylistParser().parse(text, into: live, sourceURL: sourceURL)
    }

    public static func format(for text: String, sourceURL: URL? = nil) -> LivePlaylistFormat {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("{") || value.hasPrefix("[") { return .json }
        if value.range(of: "#EXTM3U", options: [.caseInsensitive]) != nil ||
            value.range(of: "#EXTINF", options: [.caseInsensitive]) != nil {
            return .m3u
        }
        if let ext = sourceURL?.pathExtension.lowercased(), ext == "json" { return .json }
        if let ext = sourceURL?.pathExtension.lowercased(), ["m3u", "m3u8"].contains(ext) { return .m3u }
        return .txt
    }

    /// Applies the same inheritance and automatic numbering as Android's Channel.trans/live.
    public static func applyingDefaults(_ live: Live) -> Live {
        var result = live
        var number = 1
        for groupIndex in result.groups.indices {
            if result.groups[groupIndex].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.groups[groupIndex].name = "Live"
            }
            for channelIndex in result.groups[groupIndex].channels.indices {
                var channel = result.groups[groupIndex].channels[channelIndex]
                if channel.number.isEmpty {
                    channel.number = String(format: "%03d", number)
                    number += 1
                }
                if channel.tvgName.isEmpty { channel.tvgName = channel.name }
                if channel.tvgID.isEmpty { channel.tvgID = channel.tvgName }
                if channel.epg.isEmpty, !result.epg.isEmpty {
                    channel.epg = result.epg
                        .replacingOccurrences(of: "{id}", with: channel.tvgID)
                        .replacingOccurrences(of: "{name}", with: channel.tvgName)
                }
                if channel.logo.isEmpty, result.logo.contains("{") {
                    channel.logo = result.logo
                        .replacingOccurrences(of: "{id}", with: channel.tvgID)
                        .replacingOccurrences(of: "{name}", with: channel.tvgName)
                        .replacingOccurrences(of: "{logo}", with: channel.logo)
                }
                if channel.userAgent.isEmpty { channel.userAgent = result.userAgent }
                if channel.origin.isEmpty { channel.origin = result.origin }
                if channel.referer.isEmpty { channel.referer = result.referer }
                if channel.catchup == nil || channel.catchup?.isEmpty == true { channel.catchup = result.catchup }
                if (channel.catchup == nil || channel.catchup?.isEmpty == true),
                   channel.urls.contains(where: { $0.contains("/PLTV/") }) {
                    channel.catchup = .pltv
                }
                if channel.header.isEmpty {
                    channel.header = result.header
                } else {
                    channel.header = result.header.merging(channel.header) { _, channelValue in channelValue }
                }
                result.groups[groupIndex].channels[channelIndex] = channel
            }
        }
        return result
    }
}

fileprivate extension LivePlaylistParser {
    static func parseJSON(_ text: String, into live: Live) throws -> Live {
        guard let data = text.data(using: .utf8) else { throw LivePlaylistParserError.invalidJSON }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw LivePlaylistParserError.invalidJSON
        }

        let candidate: Any
        let sourceDictionary: [String: Any]?
        if let array = object as? [Any] {
            candidate = array
            sourceDictionary = nil
        } else if let dictionary = object as? [String: Any] {
            sourceDictionary = dictionary
            if let groups = dictionary["groups"] {
                candidate = groups is [Any] ? groups : [groups]
            } else if dictionary["channel"] != nil || dictionary["channels"] != nil {
                candidate = [dictionary]
            } else if let data = dictionary["data"] {
                candidate = data
            } else if let lives = dictionary["lives"] {
                candidate = lives
            } else {
                throw LivePlaylistParserError.invalidPlaylist
            }
        } else {
            sourceDictionary = nil
            throw LivePlaylistParserError.invalidPlaylist
        }

        let normalized = normalizeGroups(candidate)
        guard JSONSerialization.isValidJSONObject(normalized) else {
            throw LivePlaylistParserError.invalidJSON
        }
        do {
            let encoded = try JSONSerialization.data(withJSONObject: normalized)
            let groups = try JSONDecoder().decode([LiveGroup].self, from: encoded)
            guard !groups.isEmpty else { throw LivePlaylistParserError.invalidPlaylist }
            var result = live
            result.groups = groups
            if let sourceDictionary {
                if result.epg.isEmpty, let epg = sourceDictionary["epg"] as? String { result.epg = epg }
                if result.userAgent.isEmpty, let ua = sourceDictionary["ua"] as? String { result.userAgent = ua }
                if result.referer.isEmpty, let referer = sourceDictionary["referer"] as? String { result.referer = referer }
                if result.origin.isEmpty, let origin = sourceDictionary["origin"] as? String { result.origin = origin }
                if result.header.isEmpty, let header = sourceDictionary["header"] as? [String: String] { result.header = header }
                if result.catchup == nil,
                   let value = sourceDictionary["catchup"],
                   JSONSerialization.isValidJSONObject(value),
                   let data = try? JSONSerialization.data(withJSONObject: value) {
                    result.catchup = try? JSONDecoder().decode(Catchup.self, from: data)
                }
            }
            return result
        } catch let error as LivePlaylistParserError {
            throw error
        } catch {
            throw LivePlaylistParserError.invalidJSON
        }
    }

    static func normalizeGroups(_ value: Any) -> Any {
        if let array = value as? [Any] {
            return array.map { normalizeGroup($0) }
        }
        return [normalizeGroup(value)]
    }

    static func normalizeGroup(_ value: Any) -> Any {
        guard var dictionary = value as? [String: Any] else { return value }
        if dictionary["channel"] == nil {
            if let channels = dictionary["channels"] { dictionary["channel"] = channels }
            else if let list = dictionary["list"] { dictionary["channel"] = list }
        }
        if let channel = dictionary["channel"], !(channel is [Any]) {
            dictionary["channel"] = [channel]
        }
        if let channels = dictionary["channel"] as? [Any] {
            dictionary["channel"] = channels.map { normalizeChannel($0) }
        }
        return dictionary
    }

    static func normalizeChannel(_ value: Any) -> Any {
        guard var dictionary = value as? [String: Any] else { return value }
        if dictionary["urls"] == nil, let url = dictionary["url"] {
            dictionary["urls"] = url is [Any] ? url : [url]
        }
        let aliases = [
            "tvg-id": "tvgId",
            "tvg-name": "tvgName",
            "http-user-agent": "ua",
            "user-agent": "ua",
            "referrer": "referer"
        ]
        for (source, target) in aliases where dictionary[target] == nil {
            if let value = dictionary[source] { dictionary[target] = value }
        }
        if let header = dictionary["header"] as? String {
            dictionary["header"] = parseHeaderSpec(header)
        }
        return dictionary
    }

    static func parseM3U(_ text: String, into live: Live) -> Live {
        var result = live
        result.groups = []
        var settings = PlaylistSettings()
        var pending: PendingChannel?
        var fallbackGroup = "Live"

        for rawLine in normalizedLines(text) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            if lower.hasPrefix("#extm3u") {
                let attrs = attributes(after: line, marker: "#EXTM3U")
                if result.epg.isEmpty { result.epg = attrs["tvg-url"] ?? attrs["url-tvg"] ?? "" }
                continue
            }
            if lower.hasPrefix("#extinf:") {
                let body = String(line.drop(while: { $0 != ":" }).dropFirst())
                let comma = body.firstIndex(of: ",")
                let metadata = comma.map { String(body[..<$0]) } ?? body
                let name = comma.map { String(body[body.index(after: $0)...]).trimmingCharacters(in: .whitespaces) } ?? ""
                let attrs = attributes(in: metadata)
                var channel = Channel(name: name)
                channel.tvgID = attrs["tvg-id"] ?? attrs["tvgId"] ?? ""
                channel.tvgName = attrs["tvg-name"] ?? attrs["tvgName"] ?? ""
                channel.number = attrs["tvg-chno"] ?? attrs["tvg-channel"] ?? ""
                channel.logo = attrs["tvg-logo"] ?? ""
                channel.userAgent = attrs["http-user-agent"] ?? attrs["user-agent"] ?? settings.userAgent
                channel.format = normalizedFormat(attrs["format"] ?? settings.format)
                channel.origin = attrs["origin"] ?? settings.origin
                channel.referer = attrs["referer"] ?? attrs["referrer"] ?? settings.referer
                channel.click = attrs["click"] ?? settings.click
                channel.parse = Int(attrs["parse"] ?? "") ?? settings.parse ?? 0
                channel.catchup = catchup(from: attrs) ?? settings.catchup
                channel.header = settings.headers
                let groupName = attrs["group-title"] ?? attrs["group"] ?? fallbackGroup
                pending = PendingChannel(groupName: groupName, channel: channel)
                continue
            }
            if lower.hasPrefix("#extgrp:") {
                fallbackGroup = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("#") {
                settings.consume(line)
                continue
            }
            if settings.consume(line) { continue }
            guard line.contains("://") else { continue }
            let parts = splitURLAndHeaders(line)
            if pending == nil {
                pending = PendingChannel(groupName: fallbackGroup, channel: Channel(name: parts.url))
            }
            guard var item = pending else { continue }
            item.channel.urls.append(parts.url)
            item.channel.header = item.channel.header.merging(parts.headers) { _, newValue in newValue }
            item.channel.applyHeaderFields()
            settings.apply(to: &item.channel)
            append(item.channel, to: item.groupName, groups: &result.groups, pass: result.pass)
            pending = nil
            settings.clear()
        }
        return result
    }

    static func parseTXT(_ text: String, into live: Live) -> Live {
        var result = live
        result.groups = []
        var settings = PlaylistSettings()
        var currentGroup: String?

        for rawLine in normalizedLines(text) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.lowercased().contains("#genre#") {
                let name = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "Live"
                currentGroup = name.trimmingCharacters(in: .whitespacesAndNewlines)
                settings.clear()
                continue
            }
            if settings.consume(line) { continue }
            let split = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard split.count == 2 else { continue }
            let name = String(split[0]).trimmingCharacters(in: .whitespaces)
            let urls = String(split[1]).split(separator: "#", omittingEmptySubsequences: true)
            guard !name.isEmpty, !urls.isEmpty else { continue }
            let groupName = currentGroup ?? "Live"
            for rawURL in urls {
                let parts = splitURLAndHeaders(String(rawURL).trimmingCharacters(in: .whitespaces))
                guard parts.url.contains("://") else { continue }
                var channel = Channel(name: name)
                channel.urls = [parts.url]
                channel.header = settings.headers.merging(parts.headers) { _, newValue in newValue }
                channel.applyHeaderFields()
                settings.apply(to: &channel)
                append(channel, to: groupName, groups: &result.groups, pass: result.pass)
            }
        }
        return result
    }

    static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
    }

    static func append(_ channel: Channel, to groupName: String, groups: inout [LiveGroup], pass: Bool) {
        let parsed = splitGroupName(groupName, pass: pass)
        let index: Int
        if let found = groups.firstIndex(where: { $0.name == parsed.name && $0.pass == parsed.pass }) {
            index = found
        } else {
            groups.append(LiveGroup(name: parsed.name, pass: parsed.pass, channels: []))
            index = groups.count - 1
        }
        if let channelIndex = groups[index].channels.firstIndex(where: { $0.name == channel.name || (!channel.number.isEmpty && $0.number == channel.number) }) {
            let existing = groups[index].channels[channelIndex]
            let additions = channel.urls.filter { !existing.urls.contains($0) }
            groups[index].channels[channelIndex].urls.append(contentsOf: additions)
            if groups[index].channels[channelIndex].logo.isEmpty { groups[index].channels[channelIndex].logo = channel.logo }
            if groups[index].channels[channelIndex].tvgID.isEmpty { groups[index].channels[channelIndex].tvgID = channel.tvgID }
            if groups[index].channels[channelIndex].tvgName.isEmpty { groups[index].channels[channelIndex].tvgName = channel.tvgName }
            if groups[index].channels[channelIndex].header.isEmpty { groups[index].channels[channelIndex].header = channel.header }
        } else {
            groups[index].channels.append(channel)
        }
    }

    static func splitGroupName(_ value: String, pass: Bool) -> (name: String, pass: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return ("Live", "") }
        guard !pass, let separator = value.firstIndex(of: "_") else { return (value, "") }
        return (String(value[..<separator]), String(value[value.index(after: separator)...]))
    }

    static func attributes(after line: String, marker: String) -> [String: String] {
        let start = line.index(line.startIndex, offsetBy: min(line.count, marker.count))
        return attributes(in: String(line[start...]))
    }

    static func attributes(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        var index = text.startIndex
        while index < text.endIndex {
            while index < text.endIndex, text[index].isWhitespace || text[index] == ":" { index = text.index(after: index) }
            guard index < text.endIndex else { break }
            let keyStart = index
            while index < text.endIndex, text[index] != "=", !text[index].isWhitespace { index = text.index(after: index) }
            let key = String(text[keyStart..<index]).lowercased()
            guard !key.isEmpty else { break }
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            guard index < text.endIndex, text[index] == "=" else {
                while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
                continue
            }
            index = text.index(after: index)
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            var value = ""
            if index < text.endIndex, text[index] == "\"" {
                index = text.index(after: index)
                let valueStart = index
                while index < text.endIndex, text[index] != "\"" { index = text.index(after: index) }
                value = String(text[valueStart..<index])
                if index < text.endIndex { index = text.index(after: index) }
            } else {
                let valueStart = index
                while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
                value = String(text[valueStart..<index])
            }
            result[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return result
    }

    static func parseHeaderSpec(_ value: String) -> [String: String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if let data = trimmed.data(using: .utf8), trimmed.hasPrefix("{"),
           let object = try? JSONSerialization.jsonObject(with: data), let dictionary = object as? [String: Any] {
            return dictionary.reduce(into: [:]) { result, item in result[item.key] = String(describing: item.value) }
        }
        return trimmed.replacingOccurrences(of: "|", with: "&").split(separator: "&").reduce(into: [:]) { result, item in
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return }
            result[String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines)] = String(pair[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }

    static func splitURLAndHeaders(_ line: String) -> (url: String, headers: [String: String]) {
        let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (line.trimmingCharacters(in: .whitespaces), [:]) }
        return (String(parts[0]).trimmingCharacters(in: .whitespaces), parseHeaderSpec(String(parts[1])))
    }
}

private struct PendingChannel {
    var groupName: String
    var channel: Channel
}

private struct PlaylistSettings {
    var userAgent = ""
    var format = ""
    var origin = ""
    var referer = ""
    var click = ""
    var parse: Int?
    var catchup: Catchup?
    var headers: [String: String] = [:]

    mutating func consume(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("#exthttp:") {
            let value = String(line.dropFirst("#EXTHTTP:".count))
            headers.merge(LivePlaylistParser.parseHeaderSpec(value)) { _, newValue in newValue }
            return true
        }
        if lower.hasPrefix("#extvlcopt:") {
            let value = String(line.dropFirst("#EXTVLCOPT:".count))
            consumeKeyValue(value)
            return true
        }
        if lower.hasPrefix("#kodiprop:inputstream.adaptive.manifest_type=") {
            let value = line.split(separator: "=", maxSplits: 1).last.map(String.init) ?? ""
            format = normalizedFormat(value)
            return true
        }
        if lower.hasPrefix("#kodiprop:") { return true }
        if ["ua=", "user-agent=", "header=", "format=", "origin=", "referer=", "referrer=", "click=", "parse=", "catchup=", "catchup-source=", "catchup-days=", "catchup-replace=", "catchup-regex="].contains(where: { lower.hasPrefix($0) }) {
            consumeKeyValue(line)
            return true
        }
        return false
    }

    mutating func consumeKeyValue(_ line: String) {
        let valueLine = line.replacingOccurrences(of: "http-", with: "", options: [.caseInsensitive], range: nil)
        guard let separator = valueLine.firstIndex(of: "=") else { return }
        let rawKey = String(valueLine[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rawValue = String(valueLine[valueLine.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        switch rawKey {
        case "ua", "user-agent": userAgent = rawValue
        case "header": headers.merge(LivePlaylistParser.parseHeaderSpec(rawValue)) { _, newValue in newValue }
        case "format", "manifest_type": format = normalizedFormat(rawValue)
        case "origin": origin = rawValue
        case "referer", "referrer": referer = rawValue
        case "click": click = rawValue
        case "parse": parse = Int(rawValue)
        case "catchup": catchup = Catchup(type: rawValue)
        case "catchup-source":
            catchup = (catchup ?? Catchup())
            catchup?.source = rawValue
        case "catchup-days":
            catchup = (catchup ?? Catchup())
            catchup?.days = rawValue
        case "catchup-replace":
            catchup = (catchup ?? Catchup())
            catchup?.replace = rawValue
        case "catchup-regex":
            catchup = (catchup ?? Catchup())
            catchup?.regex = rawValue
        default:
            headers[rawKey] = rawValue
        }
        applyHeaderFields()
    }

    mutating func apply(to channel: inout Channel) {
        if channel.userAgent.isEmpty { channel.userAgent = userAgent }
        if channel.format.isEmpty { channel.format = format }
        if channel.origin.isEmpty { channel.origin = origin }
        if channel.referer.isEmpty { channel.referer = referer }
        if channel.click.isEmpty { channel.click = click }
        if channel.parse == 0 { channel.parse = parse ?? 0 }
        if channel.catchup == nil || channel.catchup?.isEmpty == true { channel.catchup = catchup }
        channel.header = headers.merging(channel.header) { _, channelValue in channelValue }
        channel.applyHeaderFields()
    }

    mutating func applyHeaderFields() {
        for (key, value) in headers {
            switch key.lowercased() {
            case "user-agent": if userAgent.isEmpty { userAgent = value }
            case "origin": if origin.isEmpty { origin = value }
            case "referer", "referrer": if referer.isEmpty { referer = value }
            default: break
            }
        }
    }

    mutating func clear() {
        userAgent = ""
        format = ""
        origin = ""
        referer = ""
        click = ""
        parse = nil
        catchup = nil
        headers = [:]
    }
}

private func catchup(from attributes: [String: String]) -> Catchup? {
    let keys = ["catchup", "catchup-source", "catchup-days", "catchup-replace", "catchup-regex"]
    guard keys.contains(where: { attributes[$0] != nil }) else { return nil }
    return Catchup(
        type: attributes["catchup"] ?? "",
        days: attributes["catchup-days"] ?? "",
        regex: attributes["catchup-regex"] ?? "",
        source: attributes["catchup-source"] ?? "",
        replace: attributes["catchup-replace"] ?? ""
    )
}

fileprivate func normalizedFormat(_ value: String) -> String {
    switch value.lowercased() {
    case "hls", "m3u8": return "application/x-mpegURL"
    case "mpd", "dash": return "application/dash+xml"
    default: return value
    }
}

fileprivate extension Channel {
    mutating func applyHeaderFields() {
        for (key, value) in header {
            switch key.lowercased() {
            case "user-agent": if userAgent.isEmpty { userAgent = value }
            case "origin": if origin.isEmpty { origin = value }
            case "referer", "referrer": if referer.isEmpty { referer = value }
            default: break
            }
        }
    }
}
