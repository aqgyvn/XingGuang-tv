import XCTest
@testable import XingGuangKit

final class ApiVodRepositoryTests: XCTestCase {
    func testJSONHomeDecodesCatalog() async throws {
        let data = Data(#"{"class":[{"type_id":"1","type_name":"电影"}],"list":[{"vod_id":"7","vod_name":"测试影片"}]}"#.utf8)
        let repository = ApiVodRepository(client: HTTPClientStub(data: data))

        let result = try await repository.home(site: Site(key: "json", name: "JSON", api: "https://example.com/api", type: 1), includeFilters: true)

        XCTAssertEqual(result.classes.first?.typeName, "电影")
        XCTAssertEqual(result.list.first?.vodName, "测试影片")
    }

    func testXMLHomeDecodesRoutes() async throws {
        let xml = """
        <rss><class><ty id="1">电影</ty></class><list><video><id>9</id><name>XML影片</name><type>电影</type><dl><dd flag="线路一">第1集$https://example.com/1.m3u8#第2集$https://example.com/2.m3u8</dd></dl></video></list></rss>
        """
        let repository = ApiVodRepository(client: HTTPClientStub(data: Data(xml.utf8)))

        let result = try await repository.home(site: Site(key: "xml", name: "XML", api: "https://example.com/api", type: 0), includeFilters: true)

        XCTAssertEqual(result.list.first?.playbackRoutes.first?.name, "线路一")
        XCTAssertEqual(result.list.first?.playbackRoutes.first?.episodes.count, 2)
    }

    func testXMLEmptyCatalogRemainsAValidEmptyResult() async throws {
        let repository = ApiVodRepository(client: HTTPClientStub(data: Data("<rss><class/><list/></rss>".utf8)))

        let result = try await repository.home(site: Site(key: "xml", name: "XML", api: "https://example.com/api", type: 0), includeFilters: true)

        XCTAssertTrue(result.classes.isEmpty)
        XCTAssertTrue(result.list.isEmpty)
    }

    func testTypeFourPlaybackUsesResolvedURL() async throws {
        let data = Data(#"{"url":"https://cdn.example.com/video.m3u8","list":[{"vod_play_url":"https://cdn.example.com/video.m3u8$$$https://cdn.example.com/fallback.m3u8"}],"format":"application/x-mpegURL","artwork":"https://cdn.example.com/poster.jpg","header":{"Referer":"https://video.example.com"},"subs":[{"url":"https://cdn.example.com/sub.vtt","name":"中文","lang":"zh-CN","format":"text/vtt"}],"danmaku":[{"url":"https://cdn.example.com/danmaku.xml","name":"弹幕"}],"drm":{"type":"widevine","key":"https://license.example.com","header":{"Authorization":"Bearer token"}}}"#.utf8)
        let repository = ApiVodRepository(client: HTTPClientStub(data: data))
        var site = Site(key: "drpy", name: "扩展", api: "https://example.com/api", type: 4)
        site.header = ["User-Agent": "XingGuang"]
        site.timeout = 30

        let request = try await repository.resolvePlayback(site: site, flag: "线路", episodeURL: "https://example.com/source")

        XCTAssertEqual(request.url, "https://cdn.example.com/video.m3u8")
        XCTAssertEqual(request.headers["User-Agent"], "XingGuang")
        XCTAssertEqual(request.headers["Referer"], "https://video.example.com")
        XCTAssertEqual(request.artwork, "https://cdn.example.com/poster.jpg")
        XCTAssertEqual(request.subtitles.first?.language, "zh-CN")
        XCTAssertEqual(request.danmaku.first?.url, "https://cdn.example.com/danmaku.xml")
        XCTAssertEqual(request.drm?.headers["Authorization"], "Bearer token")
        XCTAssertEqual(request.timeout, 30)
    }

    func testTypeFourPlaybackUsesResultJSONParseDirective() async throws {
        let client = HTTPClientStub(responses: [
            Data(#"{"url":"https://vip.example/episode","playUrl":"json:https://parser.example/?url=","parse":1}"#.utf8),
            Data(#"{"url":"https://cdn.example/video.m3u8","ua":"ParserUA"}"#.utf8)
        ])
        let repository = ApiVodRepository(client: client)
        let site = Site(key: "drpy", name: "扩展", api: "https://example.com/api", type: 4)

        let request = try await repository.resolvePlayback(
            context: VodPlaybackContext(),
            site: site,
            flag: "qq",
            episodeURL: "https://vip.example/episode"
        )

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[1].url.absoluteString, "https://parser.example/?url=https://vip.example/episode")
        XCTAssertEqual(request.url, "https://cdn.example/video.m3u8")
        XCTAssertEqual(request.headers["User-Agent"], "ParserUA")
        XCTAssertFalse(request.requiresSniffing)
    }

    func testRemoteShortExtensionKeepsAPIRequestAsGET() async throws {
        let longExtensionURL = "https://example.com/" + String(repeating: "x", count: 1_100)
        let client = HTTPClientStub(responses: [Data("short-extension".utf8), Data(#"{"list":[]}"#.utf8)])
        let repository = ApiVodRepository(client: client)
        var site = Site(key: "json", name: "JSON", api: "https://example.com/api", type: 1)
        site.ext = .string(longExtensionURL)

        _ = try await repository.home(site: site, includeFilters: true)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[1].method, .get)
        XCTAssertEqual(URLComponents(url: client.requests[1].url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "extend" })?.value, "short-extension")
    }
}

private final class HTTPClientStub: HTTPClient, @unchecked Sendable {
    private var responses: [Data]
    private(set) var requests: [HTTPRequest] = []

    init(data: Data) { self.responses = [data] }
    init(responses: [Data]) { self.responses = responses }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let data = responses.count > 1 ? responses.removeFirst() : responses.first ?? Data()
        return HTTPResponse(statusCode: 200, url: request.url, headers: [:], data: data)
    }
}
