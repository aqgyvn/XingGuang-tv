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
    public var groups: [LiveGroup]
    public var boot: Bool
    public var pass: Bool

    enum CodingKeys: String, CodingKey {
        case name, url, api, ext, jar, click, logo, epg, origin, referer
        case timeZone, timeout, header, groups, boot, pass
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

    enum CodingKeys: String, CodingKey {
        case urls, number, logo, epg, name, click, format, origin, referer, header, parse
        case userAgent = "ua"
        case tvgID = "tvgId"
        case tvgName
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

    enum CodingKeys: String, CodingKey {
        case title, start, end
        case description = "desc"
    }

    public init(title: String = "", start: String = "", end: String = "", description: String = "") {
        self.title = title
        self.start = start
        self.end = end
        self.description = description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.string(.title)
        start = container.string(.start)
        end = container.string(.end)
        description = container.string(.description)
    }
}
