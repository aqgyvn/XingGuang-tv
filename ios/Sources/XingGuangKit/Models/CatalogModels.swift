import Foundation

public struct VodConfigDocument: Codable, Equatable {
    public var spider: String
    public var wallpaper: String
    public var logo: String
    public var notice: String
    public var sites: [Site]
    public var parses: [ParseRule]
    public var lives: [Live]
    public var flags: [String]
    public var ads: [String]

    enum CodingKeys: String, CodingKey {
        case spider, wallpaper, logo, notice, sites, parses, lives, flags, ads
    }

    public init(
        spider: String = "",
        wallpaper: String = "",
        logo: String = "",
        notice: String = "",
        sites: [Site] = [],
        parses: [ParseRule] = [],
        lives: [Live] = [],
        flags: [String] = [],
        ads: [String] = []
    ) {
        self.spider = spider
        self.wallpaper = wallpaper
        self.logo = logo
        self.notice = notice
        self.sites = sites
        self.parses = parses
        self.lives = lives
        self.flags = flags
        self.ads = ads
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spider = container.string(.spider)
        wallpaper = container.string(.wallpaper)
        logo = container.string(.logo)
        notice = container.string(.notice)
        sites = container.array(Site.self, .sites)
        parses = container.array(ParseRule.self, .parses)
        lives = container.array(Live.self, .lives)
        flags = container.array(String.self, .flags)
        ads = container.array(String.self, .ads)
    }
}

public struct Site: Codable, Equatable, Identifiable {
    public var id: String { key }
    public var key: String
    public var name: String
    public var api: String
    public var ext: JSONValue?
    public var jar: String
    public var click: String
    public var playURL: String
    public var type: Int
    public var hide: Int
    public var indexs: Int
    public var timeout: Int
    public var searchable: Int
    public var changeable: Int
    public var quickSearch: Int
    public var categories: [String]
    public var header: [String: String]
    public var style: SiteStyle?

    enum CodingKeys: String, CodingKey {
        case key, name, api, ext, jar, click, type, hide, indexs, timeout
        case searchable, changeable, quickSearch, categories, header, style
        case playURL = "playUrl"
    }

    public init(key: String = "", name: String = "", api: String = "", type: Int = 0) {
        self.key = key
        self.name = name
        self.api = api
        self.ext = nil
        self.jar = ""
        self.click = ""
        self.playURL = ""
        self.type = type
        self.hide = 0
        self.indexs = 0
        self.timeout = 0
        self.searchable = 1
        self.changeable = 1
        self.quickSearch = 1
        self.categories = []
        self.header = [:]
        self.style = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.string(.key)
        name = container.string(.name)
        api = container.string(.api)
        ext = try? container.decodeIfPresent(JSONValue.self, forKey: .ext)
        jar = container.string(.jar)
        click = container.string(.click)
        playURL = container.string(.playURL)
        type = container.integer(.type)
        hide = container.integer(.hide)
        indexs = container.integer(.indexs)
        timeout = container.integer(.timeout)
        searchable = container.integer(.searchable, default: 1)
        changeable = container.integer(.changeable, default: 1)
        quickSearch = container.integer(.quickSearch, default: 1)
        categories = container.array(String.self, .categories)
        header = container.dictionary(String.self, .header)
        style = try? container.decodeIfPresent(SiteStyle.self, forKey: .style)
    }
}

public struct SiteStyle: Codable, Equatable {
    public var type: String
    public var ratio: Double

    enum CodingKeys: String, CodingKey {
        case type, ratio
    }

    public init(type: String = "rect", ratio: Double = 0.75) {
        self.type = type
        self.ratio = ratio
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.string(.type, default: "rect")
        ratio = container.double(.ratio, default: 0.75)
    }
}

public struct ParseRule: Codable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var type: Int
    public var url: String
    public var ext: ParseExtension?

    enum CodingKeys: String, CodingKey {
        case name, type, url, ext
    }

    public init(name: String = "", type: Int = 0, url: String = "", ext: ParseExtension? = nil) {
        self.name = name
        self.type = type
        self.url = url
        self.ext = ext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.string(.name)
        type = container.integer(.type)
        url = container.string(.url)
        ext = try? container.decodeIfPresent(ParseExtension.self, forKey: .ext)
    }
}

public struct ParseExtension: Codable, Equatable {
    public var flag: [String]
    public var header: [String: String]

    enum CodingKeys: String, CodingKey {
        case flag, header
    }

    public init(flag: [String] = [], header: [String: String] = [:]) {
        self.flag = flag
        self.header = header
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flag = container.array(String.self, .flag)
        header = container.dictionary(String.self, .header)
    }
}

public struct VodResult: Codable, Equatable {
    public var classes: [VodClass]
    public var list: [Vod]
    public var filters: [String: [VodFilter]]
    public var url: String
    public var header: [String: String]
    public var message: String
    public var playURL: String
    public var artwork: String
    public var subtitles: [SubtitleResource]
    public var drm: PlaybackDRM?
    public var flag: String
    public var format: String
    public var parse: Int
    public var pageCount: Int

    enum CodingKeys: String, CodingKey {
        case classes = "class"
        case list, filters, url, header, flag, format, parse, artwork, drm
        case message = "msg"
        case playURL = "playUrl"
        case pageCount = "pagecount"
        case subtitles = "subs"
    }

    public init(
        classes: [VodClass] = [],
        list: [Vod] = [],
        filters: [String: [VodFilter]] = [:],
        url: String = "",
        header: [String: String] = [:],
        message: String = "",
        playURL: String = "",
        artwork: String = "",
        subtitles: [SubtitleResource] = [],
        drm: PlaybackDRM? = nil,
        flag: String = "",
        format: String = "",
        parse: Int = 0,
        pageCount: Int = 0
    ) {
        self.classes = classes
        self.list = list
        self.filters = filters
        self.url = url
        self.header = header
        self.message = message
        self.playURL = playURL
        self.artwork = artwork
        self.subtitles = subtitles
        self.drm = drm
        self.flag = flag
        self.format = format
        self.parse = parse
        self.pageCount = pageCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classes = container.array(VodClass.self, .classes)
        list = container.array(Vod.self, .list)
        filters = container.dictionary([VodFilter].self, .filters)
        if let directURL = try? container.decode(String.self, forKey: .url) {
            url = directURL
        } else if let value = try? container.decode(VodURL.self, forKey: .url) {
            url = value.current
        } else if let values = try? container.decode([String].self, forKey: .url) {
            url = values.count > 1 ? values[1] : ""
        } else {
            url = ""
        }
        header = container.dictionary(String.self, .header)
        message = container.string(.message)
        playURL = container.string(.playURL)
        artwork = container.string(.artwork)
        subtitles = container.array(SubtitleResource.self, .subtitles)
        drm = try? container.decodeIfPresent(PlaybackDRM.self, forKey: .drm)
        flag = container.string(.flag)
        format = container.string(.format)
        parse = container.integer(.parse)
        pageCount = container.integer(.pageCount)
    }
}

private struct VodURL: Codable {
    var values: [VodFilterValue]
    var position: Int

    var current: String {
        guard values.indices.contains(position) else { return values.first?.value ?? "" }
        return values[position].value
    }

    enum CodingKeys: String, CodingKey {
        case values, position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        values = container.array(VodFilterValue.self, .values)
        position = container.integer(.position)
    }
}

public struct VodClass: Codable, Equatable, Identifiable {
    public var id: String { typeID }
    public var typeID: String
    public var typeName: String

    enum CodingKeys: String, CodingKey {
        case typeID = "type_id"
        case typeName = "type_name"
    }

    public init(typeID: String = "", typeName: String = "") {
        self.typeID = typeID
        self.typeName = typeName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeID = container.string(.typeID)
        typeName = container.string(.typeName)
    }
}

public struct VodFilter: Codable, Equatable, Identifiable {
    public var id: String { key }
    public var key: String
    public var name: String
    public var initialValue: String
    public var values: [VodFilterValue]

    enum CodingKeys: String, CodingKey {
        case key, name
        case initialValue = "init"
        case values = "value"
    }

    public init(key: String = "", name: String = "", initialValue: String = "", values: [VodFilterValue] = []) {
        self.key = key
        self.name = name
        self.initialValue = initialValue
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.string(.key)
        name = container.string(.name)
        initialValue = container.string(.initialValue)
        values = container.array(VodFilterValue.self, .values)
    }
}

public struct VodFilterValue: Codable, Equatable, Identifiable {
    public var id: String { value }
    public var name: String
    public var value: String

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case value = "v"
    }

    public init(name: String = "", value: String = "") {
        self.name = name
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.string(.name)
        value = container.string(.value)
    }
}

public struct Vod: Codable, Equatable, Identifiable {
    public var id: String { vodID }
    public var vodID: String
    public var vodName: String
    public var typeName: String
    public var vodPic: String
    public var vodRemarks: String
    public var vodYear: String
    public var vodArea: String
    public var vodDirector: String
    public var vodActor: String
    public var vodContent: String
    public var vodPlayFrom: String
    public var vodPlayURL: String
    public var vodTag: String

    enum CodingKeys: String, CodingKey {
        case vodID = "vod_id"
        case vodName = "vod_name"
        case typeName = "type_name"
        case vodPic = "vod_pic"
        case vodRemarks = "vod_remarks"
        case vodYear = "vod_year"
        case vodArea = "vod_area"
        case vodDirector = "vod_director"
        case vodActor = "vod_actor"
        case vodContent = "vod_content"
        case vodPlayFrom = "vod_play_from"
        case vodPlayURL = "vod_play_url"
        case vodTag = "vod_tag"
    }

    public init(
        vodID: String = "",
        vodName: String = "",
        typeName: String = "",
        vodPic: String = "",
        vodRemarks: String = "",
        vodYear: String = "",
        vodArea: String = "",
        vodDirector: String = "",
        vodActor: String = "",
        vodContent: String = "",
        vodPlayFrom: String = "",
        vodPlayURL: String = "",
        vodTag: String = ""
    ) {
        self.vodID = vodID
        self.vodName = vodName
        self.typeName = typeName
        self.vodPic = vodPic
        self.vodRemarks = vodRemarks
        self.vodYear = vodYear
        self.vodArea = vodArea
        self.vodDirector = vodDirector
        self.vodActor = vodActor
        self.vodContent = vodContent
        self.vodPlayFrom = vodPlayFrom
        self.vodPlayURL = vodPlayURL
        self.vodTag = vodTag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vodID = container.string(.vodID)
        vodName = container.string(.vodName)
        typeName = container.string(.typeName)
        vodPic = container.string(.vodPic)
        vodRemarks = container.string(.vodRemarks)
        vodYear = container.string(.vodYear)
        vodArea = container.string(.vodArea)
        vodDirector = container.string(.vodDirector)
        vodActor = container.string(.vodActor)
        vodContent = container.string(.vodContent)
        vodPlayFrom = container.string(.vodPlayFrom)
        vodPlayURL = container.string(.vodPlayURL)
        vodTag = container.string(.vodTag)
    }
}

public struct PlaybackRoute: Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var episodes: [PlaybackEpisode]

    public init(name: String, episodes: [PlaybackEpisode]) {
        self.name = name
        self.episodes = episodes
    }
}

public struct PlaybackEpisode: Equatable, Identifiable {
    public var id: String { "\(name):\(url)" }
    public var name: String
    public var url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

public extension Vod {
    var playbackRoutes: [PlaybackRoute] {
        let names = vodPlayFrom.components(separatedBy: "$$$")
        let routeURLs = vodPlayURL.components(separatedBy: "$$$")
        return routeURLs.enumerated().compactMap { index, value in
            let episodes = value.components(separatedBy: "#").enumerated().compactMap { episodeIndex, item -> PlaybackEpisode? in
                let pair = item.components(separatedBy: "$" )
                let url = pair.count > 1 ? pair.dropFirst().joined(separator: "$") : item
                guard !url.isEmpty else { return nil }
                let name = pair.count > 1 && !pair[0].isEmpty ? pair[0] : String(format: "%02d", episodeIndex + 1)
                return PlaybackEpisode(name: name, url: url)
            }
            guard !episodes.isEmpty else { return nil }
            let name = names.indices.contains(index) && !names[index].isEmpty ? names[index] : "线路 \(index + 1)"
            return PlaybackRoute(name: name, episodes: episodes)
        }
    }
}

public enum PlayerEnginePreference: String, Codable, Equatable, CaseIterable {
    case automatic
    case avPlayer
    case vlc
}

public struct SubtitleResource: Codable, Equatable, Identifiable {
    public var id: String { url }
    public var url: String
    public var name: String
    public var language: String
    public var format: String

    enum CodingKeys: String, CodingKey {
        case url, name, format
        case language = "lang"
    }

    public init(url: String, name: String = "", language: String = "", format: String = "") {
        self.url = url
        self.name = name
        self.language = language
        self.format = format
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.string(.url)
        name = container.string(.name)
        language = container.string(.language)
        format = container.string(.format)
    }
}

public struct PlaybackDRM: Codable, Equatable {
    public var type: String
    public var key: String
    public var headers: [String: String]

    enum CodingKeys: String, CodingKey {
        case type, key
        case headers = "header"
    }

    public init(type: String = "", key: String = "", headers: [String: String] = [:]) {
        self.type = type
        self.key = key
        self.headers = headers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.string(.type)
        key = container.string(.key)
        headers = container.dictionary(String.self, .headers)
    }
}

public struct PlaybackRequest: Codable, Equatable {
    public var url: String
    public var headers: [String: String]
    public var cookies: [String: String]
    public var format: String
    public var artwork: String
    public var mediaType: String
    public var subtitles: [SubtitleResource]
    public var drm: PlaybackDRM?
    public var timeout: TimeInterval
    public var enginePreference: PlayerEnginePreference

    public init(
        url: String,
        headers: [String: String] = [:],
        cookies: [String: String] = [:],
        format: String = "",
        artwork: String = "",
        mediaType: String = "",
        subtitles: [SubtitleResource] = [],
        drm: PlaybackDRM? = nil,
        timeout: TimeInterval = 15,
        enginePreference: PlayerEnginePreference = .automatic
    ) {
        self.url = url
        self.headers = headers
        self.cookies = cookies
        self.format = format
        self.artwork = artwork
        self.mediaType = mediaType
        self.subtitles = subtitles
        self.drm = drm
        self.timeout = timeout
        self.enginePreference = enginePreference
    }
}
