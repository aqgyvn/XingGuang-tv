import XCTest
@testable import XingGuangKit

final class PlaybackParseResolverTests: XCTestCase {
    func testDirectMediaURLDoesNotEnterParsingChain() async throws {
        let client = ParseHTTPClientStub(responses: [])
        let resolver = PlaybackParseResolver(client: client)

        let request = try await resolver.resolve(
            result: VodResult(url: "https://cdn.example/video.m3u8"),
            site: Site(key: "api", type: 1),
            context: VodPlaybackContext(),
            originalURL: "https://cdn.example/video.m3u8",
            flag: "线路",
            inferParsingForUnknownURL: true
        )

        XCTAssertEqual(request.url, "https://cdn.example/video.m3u8")
        XCTAssertFalse(request.requiresSniffing)
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testUnknownPageFallsBackToWebSniffing() async throws {
        let resolver = PlaybackParseResolver(client: ParseHTTPClientStub(responses: []))
        var site = Site(key: "api", type: 1)
        site.click = "document.querySelector('video')?.play();"

        let request = try await resolver.resolve(
            result: VodResult(url: "https://video.example/player.html?url=https://vip.example/id"),
            site: site,
            context: VodPlaybackContext(),
            originalURL: "https://video.example/player.html?url=https://vip.example/id",
            flag: "线路",
            inferParsingForUnknownURL: true
        )

        XCTAssertTrue(request.requiresSniffing)
        XCTAssertEqual(request.url, "https://video.example/player.html?url=https://vip.example/id")
        XCTAssertEqual(request.sniffScript, site.click)
    }

    func testRawPlayURLBecomesWebParserPrefix() async throws {
        let resolver = PlaybackParseResolver(client: ParseHTTPClientStub(responses: []))
        var site = Site(key: "api", type: 1)
        site.playURL = "https://parser.example/?url="

        let request = try await resolver.resolve(
            result: VodResult(url: "https://vip.example/episode"),
            site: site,
            context: VodPlaybackContext(),
            originalURL: "https://vip.example/episode",
            flag: "qq",
            inferParsingForUnknownURL: true
        )

        XCTAssertEqual(request.url, "https://parser.example/?url=https://vip.example/episode")
        XCTAssertTrue(request.requiresSniffing)
    }

    func testJSONDirectiveResolvesNestedURLAndWhitelistsHeaders() async throws {
        let data = Data(#"{"data":{"url":"https://cdn.example/video.m3u8"},"header":{"User-Agent":"Parser","Referer":"https://vip.example/","Authorization":"secret"}}"#.utf8)
        let client = ParseHTTPClientStub(responses: [data])
        let resolver = PlaybackParseResolver(client: client)

        let request = try await resolver.resolve(
            result: VodResult(url: "https://vip.example/episode", playURL: "json:https://parser.example/?url="),
            site: Site(key: "api", type: 1),
            context: VodPlaybackContext(),
            originalURL: "https://vip.example/episode",
            flag: "qq",
            inferParsingForUnknownURL: false
        )

        XCTAssertEqual(client.requests.first?.url.absoluteString, "https://parser.example/?url=https://vip.example/episode")
        XCTAssertEqual(request.url, "https://cdn.example/video.m3u8")
        XCTAssertEqual(request.headers["User-Agent"], "Parser")
        XCTAssertEqual(request.headers["Referer"], "https://vip.example/")
        XCTAssertNil(request.headers["Authorization"])
        XCTAssertFalse(request.requiresSniffing)
    }

    func testNamedAndroidExtensionParserReturnsExplicitError() async throws {
        let resolver = PlaybackParseResolver(client: ParseHTTPClientStub(responses: []))
        let context = VodPlaybackContext(parses: [ParseRule(name: "扩展", type: 2, url: "asset://parse.js")])

        do {
            _ = try await resolver.resolve(
                result: VodResult(url: "https://vip.example/episode", playURL: "parse:扩展"),
                site: Site(key: "api", type: 1),
                context: context,
                originalURL: "https://vip.example/episode",
                flag: "qq",
                inferParsingForUnknownURL: false
            )
            XCTFail("Expected unsupported dependency")
        } catch let error as VodRepositoryError {
            guard case .unsupportedDependency = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testAggregateParserUsesFlagMatchedJSONRule() async throws {
        let data = Data(#"{"url":"https://cdn.example/video.mp4"}"#.utf8)
        let client = ParseHTTPClientStub(responses: [data])
        let resolver = PlaybackParseResolver(client: client)
        let context = VodPlaybackContext(
            parses: [
                ParseRule(name: "其他", type: 1, url: "https://wrong.example/?url=", ext: ParseExtension(flag: ["youku"])),
                ParseRule(name: "腾讯", type: 1, url: "https://right.example/?url=", ext: ParseExtension(flag: ["qq"]))
            ],
            flags: ["qq"]
        )

        let request = try await resolver.resolve(
            result: VodResult(url: "https://vip.example/episode"),
            site: Site(key: "api", type: 1),
            context: context,
            originalURL: "https://vip.example/episode",
            flag: "qq",
            inferParsingForUnknownURL: false
        )

        XCTAssertTrue(client.requests.first?.url.absoluteString.hasPrefix("https://right.example/") == true)
        XCTAssertEqual(request.url, "https://cdn.example/video.mp4")
    }
}

private final class ParseHTTPClientStub: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [Data]
    private var storedRequests: [HTTPRequest] = []

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    init(responses: [Data]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.lock()
        storedRequests.append(request)
        let data = responses.isEmpty ? Data() : responses.removeFirst()
        lock.unlock()
        return HTTPResponse(statusCode: 200, url: request.url, headers: [:], data: data)
    }
}
