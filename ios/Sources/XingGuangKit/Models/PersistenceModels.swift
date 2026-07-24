import Foundation

public enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            guard let data = try? JSONEncoder().encode(self) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        case .null:
            return ""
        }
    }
}

public struct TrackRecord: Codable, Equatable, Identifiable {
    public var id: Int64?
    public var type: Int
    public var key: String
    public var name: String
    public var format: String
    public var selected: Bool

    public init(id: Int64? = nil, type: Int = 0, key: String = "", name: String = "", format: String = "", selected: Bool = false) {
        self.id = id
        self.type = type
        self.key = key
        self.name = name
        self.format = format
        self.selected = selected
    }
}

public struct ConfigRecord: Codable, Equatable, Identifiable {
    public var id: Int
    public var type: Int
    public var time: Int64
    public var url: String
    public var json: String
    public var name: String
    public var logo: String
    public var home: String
    public var parse: String

    enum CodingKeys: String, CodingKey {
        case id, type, time, url, json, name, logo, home, parse
    }

    public init(
        id: Int = 0,
        type: Int = 0,
        time: Int64 = 0,
        url: String = "",
        json: String = "",
        name: String = "",
        logo: String = "",
        home: String = "",
        parse: String = ""
    ) {
        self.id = id
        self.type = type
        self.time = time
        self.url = url
        self.json = json
        self.name = name
        self.logo = logo
        self.home = home
        self.parse = parse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.integer(.id)
        type = container.integer(.type)
        time = container.int64(.time)
        url = container.string(.url)
        json = container.string(.json)
        name = container.string(.name)
        logo = container.string(.logo)
        home = container.string(.home)
        parse = container.string(.parse)
    }
}

public struct History: Codable, Equatable, Identifiable {
    public var id: String { key }
    public var key: String
    public var vodPic: String
    public var vodName: String
    public var vodFlag: String
    public var vodRemarks: String
    public var episodeURL: String
    public var reverseSort: Bool
    public var reversePlay: Bool
    public var createTime: Int64
    public var opening: Int64
    public var ending: Int64
    public var position: Int64
    public var duration: Int64
    public var speed: Double
    public var scale: Int
    public var configID: Int

    enum CodingKeys: String, CodingKey {
        case key, vodPic, vodName, vodFlag, vodRemarks, createTime
        case opening, ending, position, duration, speed, scale
        case episodeURL = "episodeUrl"
        case reverseSort = "revSort"
        case reversePlay = "revPlay"
        case configID = "cid"
    }

    public init(key: String = "", vodName: String = "", vodPic: String = "") {
        self.key = key
        self.vodPic = vodPic
        self.vodName = vodName
        self.vodFlag = ""
        self.vodRemarks = ""
        self.episodeURL = ""
        self.reverseSort = false
        self.reversePlay = false
        self.createTime = 0
        self.opening = -1
        self.ending = -1
        self.position = -1
        self.duration = -1
        self.speed = 1
        self.scale = -1
        self.configID = 0
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.string(.key)
        vodPic = container.string(.vodPic)
        vodName = container.string(.vodName)
        vodFlag = container.string(.vodFlag)
        vodRemarks = container.string(.vodRemarks)
        episodeURL = container.string(.episodeURL)
        reverseSort = container.boolean(.reverseSort)
        reversePlay = container.boolean(.reversePlay)
        createTime = container.int64(.createTime)
        opening = container.int64(.opening, default: -1)
        ending = container.int64(.ending, default: -1)
        position = container.int64(.position, default: -1)
        duration = container.int64(.duration, default: -1)
        speed = container.double(.speed, default: 1)
        scale = container.integer(.scale, default: -1)
        configID = container.integer(.configID)
    }
}

public struct Keep: Codable, Equatable, Identifiable {
    public var id: String { key }
    public var key: String
    public var siteName: String
    public var vodName: String
    public var vodPic: String
    public var createTime: Int64
    public var type: Int
    public var configID: Int

    enum CodingKeys: String, CodingKey {
        case key, siteName, vodName, vodPic, createTime, type
        case configID = "cid"
    }

    public init(
        key: String = "",
        siteName: String = "",
        vodName: String = "",
        vodPic: String = "",
        createTime: Int64 = 0,
        type: Int = 0,
        configID: Int = 0
    ) {
        self.key = key
        self.siteName = siteName
        self.vodName = vodName
        self.vodPic = vodPic
        self.createTime = createTime
        self.type = type
        self.configID = configID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.string(.key)
        siteName = container.string(.siteName)
        vodName = container.string(.vodName)
        vodPic = container.string(.vodPic)
        createTime = container.int64(.createTime)
        type = container.integer(.type)
        configID = container.integer(.configID)
    }
}

public struct BackupDocument: Codable, Equatable {
    public var sites: [Site]
    public var lives: [Live]
    public var keeps: [Keep]
    public var configs: [ConfigRecord]
    public var histories: [History]
    public var preferences: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case sites = "site"
        case lives = "live"
        case keeps = "keep"
        case configs = "config"
        case histories = "history"
        case preferences = "prefers"
    }

    public init(
        sites: [Site] = [],
        lives: [Live] = [],
        keeps: [Keep] = [],
        configs: [ConfigRecord] = [],
        histories: [History] = [],
        preferences: [String: JSONValue] = [:]
    ) {
        self.sites = sites
        self.lives = lives
        self.keeps = keeps
        self.configs = configs
        self.histories = histories
        self.preferences = preferences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sites = container.array(Site.self, .sites)
        lives = container.array(Live.self, .lives)
        keeps = container.array(Keep.self, .keeps)
        configs = container.array(ConfigRecord.self, .configs)
        histories = container.array(History.self, .histories)
        preferences = container.dictionary(JSONValue.self, .preferences)
    }
}
