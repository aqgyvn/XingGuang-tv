import Foundation
import XCTest
@testable import XingGuangKit

final class LiveRepositoryTests: XCTestCase {
    func testJSONPlaylistDecodesGroupsAndMultipleURLs() throws {
        let json = #"[{"name":"News","channel":[{"name":"Channel 1","tvgId":"news1","urls":["https://one.example/live.m3u8","https://two.example/live.m3u8"],"logo":"https://img.example/logo.png"}]}]"#

        let live = try LivePlaylistParser.parse(Data(json.utf8), into: Live(name: "fixture"))

        XCTAssertEqual(live.groups.count, 1)
        XCTAssertEqual(live.groups[0].name, "News")
        XCTAssertEqual(live.groups[0].channels[0].urls.count, 2)
        XCTAssertEqual(live.groups[0].channels[0].number, "001")
        XCTAssertEqual(live.groups[0].channels[0].tvgID, "news1")
    }

    func testM3UParsesMetadataHeadersAndMergesSameChannel() throws {
        let m3u = """
        #EXTM3U tvg-url="https://epg.example/guide.xml"
        #EXTVLCOPT:http-user-agent=FixtureAgent/1.0
        #EXTINF:-1 tvg-id="news1" tvg-name="News One" tvg-logo="https://img.example/1.png" group-title="News",News One
        https://one.example/live.m3u8|Referer=https://source.example&Origin=https://origin.example
        #EXTINF:-1 tvg-id="news1" group-title="News",News One
        https://two.example/live.m3u8
        """

        let live = try LivePlaylistParser.parse(m3u, into: Live(name: "fixture"))
        let channel = try XCTUnwrap(live.groups.first?.channels.first)

        XCTAssertEqual(live.epg, "https://epg.example/guide.xml")
        XCTAssertEqual(channel.urls, ["https://one.example/live.m3u8", "https://two.example/live.m3u8"])
        XCTAssertEqual(channel.userAgent, "FixtureAgent/1.0")
        XCTAssertEqual(channel.referer, "https://source.example")
        XCTAssertEqual(channel.origin, "https://origin.example")
        XCTAssertEqual(channel.logo, "https://img.example/1.png")
    }

    func testTXTParsesGenreSettingsAndAlternateLines() throws {
        let txt = """
        News,#genre#
        ua=FixtureAgent/2.0
        header=Referer=https://source.example
        News One,https://one.example/live.m3u8|Origin=https://origin.example#https://two.example/live.m3u8
        """

        let live = try LivePlaylistParser.parse(txt, into: Live(name: "fixture"))
        let channel = try XCTUnwrap(live.groups.first?.channels.first)

        XCTAssertEqual(live.groups.first?.name, "News")
        XCTAssertEqual(channel.urls.count, 2)
        XCTAssertEqual(channel.userAgent, "FixtureAgent/2.0")
        XCTAssertEqual(channel.referer, "https://source.example")
        XCTAssertEqual(channel.origin, "https://origin.example")
    }

    func testInlineGroupsDoNotRequireNetwork() async throws {
        let inline = Live(name: "inline", groups: [
            LiveGroup(name: "News", channels: [Channel(name: "One", urls: ["https://example.com/live.m3u8"])])
        ])
        let repository = DefaultLiveRepository(client: UnusedLiveHTTPClient())

        let loaded = try await repository.load(inline)

        XCTAssertEqual(loaded.groups.first?.channels.first?.number, "001")
    }

    func testRepositoryRoutesDynamicLiveContentThroughLoader() async throws {
        let json = #"[{"name":"Dynamic","channel":[{"name":"Channel","url":"https://example.com/live.m3u8"}]}]"#
        let liveRepository = DefaultLiveRepository(
            client: UnusedLiveHTTPClient(),
            dynamicContentLoader: { live in
                XCTAssertEqual(live.api, "https://example.com/spider.js")
                return json
            }
        )
        var source = Live(name: "dynamic", url: "https://example.com/source")
        source.api = "https://example.com/spider.js"

        let loaded = try await liveRepository.load(source)

        XCTAssertEqual(loaded.groups.first?.name, "Dynamic")
        XCTAssertEqual(loaded.groups.first?.channels.first?.number, "001")
    }

    func testRepositoryLoadsLocalJSON() async throws {
        let json = #"[{"name":"Sports","channel":[{"name":"Match","urls":["https://example.com/match.m3u8"]}]}]"#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("xingguang-live-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try await DefaultLiveRepository(client: UnusedLiveHTTPClient()).load(Live(name: "local", url: url.path))

        XCTAssertEqual(loaded.groups.first?.name, "Sports")
        XCTAssertEqual(loaded.groups.first?.channels.first?.name, "Match")
    }

    func testJSONEpgParsesAndroidShape() throws {
        let json = #"{"key":"news1","date":"2026-07-25","epg_data":[{"title":"Morning News","start":"08:00","end":"09:00","desc":"Fixture"}]}"#

        let epg = try EpgParser.parse(Data(json.utf8))

        XCTAssertEqual(epg.count, 1)
        XCTAssertEqual(epg[0].key, "news1")
        XCTAssertEqual(epg[0].date, "2026-07-25")
        XCTAssertEqual(epg[0].list.first?.title, "Morning News")
        XCTAssertEqual(epg[0].list.first?.description, "Fixture")
    }

    func testXMLTVGroupsProgramsByChannelAndDate() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="news1"><display-name>News One</display-name></channel>
          <programme start="20260725120000 +0000" stop="20260725130000 +0000" channel="news1">
            <title>Midday News</title><desc>XML fixture</desc>
          </programme>
        </tv>
        """

        let epg = try EpgParser.parse(Data(xml.utf8), channelKeys: ["news1"])

        XCTAssertEqual(epg.count, 1)
        XCTAssertEqual(epg[0].key, "news1")
        XCTAssertEqual(epg[0].list.first?.title, "Midday News")
        XCTAssertEqual(epg[0].list.first?.description, "XML fixture")
        XCTAssertFalse(epg[0].list.first?.start.isEmpty ?? true)
    }

    func testGzipXMLTVIsDecompressedAndParsed() throws {
        let encoded = "H4sIAAAAAAAEALMpKbOzKSjKTy9KzM1NVSguSSwqsVUyMjAyMzA3MjU0MgACBW0QqQSUzC9AkjNGlkvOSMzLS82xVcpLLS82VLKzKcksyUm1c87PLShKLS5OTVHwA0rY6EOEbfThVgLZQCcAALMuZDiHAAAA"
        let data = try XCTUnwrap(Data(base64Encoded: encoded))

        let epg = try EpgParser.parse(data, channelKeys: ["news1"])

        XCTAssertEqual(epg.first?.list.first?.title, "Compressed News")
    }

    func testCatchupTemplateBuildsReplayURLAndInheritsToChannel() throws {
        let json = #"{"name":"Replay","catchup":{"type":"append","days":"7","regex":"/live/","source":"?playseek=${(b)yyyyMMddHHmmss}-${(e)yyyyMMddHHmmss}","replace":"/live/,/timeshift/"},"groups":[{"name":"News","channel":[{"name":"One","urls":["https://example.com/live/one.m3u8"]}]}]}"#
        let live = try LivePlaylistParser.parse(json, into: Live(name: "fixture"))
        let channel = try XCTUnwrap(live.groups.first?.channels.first)
        let programme = EpgData(
            title: "Morning",
            start: "08:00",
            end: "09:00",
            startTime: 1_759_737_600_000,
            endTime: 1_759_741_200_000
        )

        XCTAssertEqual(channel.catchup, live.catchup)
        let replay = try XCTUnwrap(live.catchup?.replayURL(
            baseURL: channel.urls[0],
            programme: programme,
            now: Date(timeIntervalSince1970: 1_759_737_601),
            timeZone: TimeZone(secondsFromGMT: 0)!
        ))
        XCTAssertTrue(replay.contains("/timeshift/one.m3u8"))
        XCTAssertTrue(replay.contains("playseek="))
    }

    func testXMLTVCarriesEpochTimesForCatchup() throws {
        let xml = """
        <tv><programme start="20260725120000 +0000" stop="20260725130000 +0000" channel="news1">
          <title>Midday News</title>
        </programme></tv>
        """
        let epg = try EpgParser.parse(Data(xml.utf8), channelKeys: ["news1"])
        let item = try XCTUnwrap(epg.first?.list.first)
        XCTAssertGreaterThan(item.startTime, 0)
        XCTAssertGreaterThan(item.endTime, item.startTime)
    }

    func testPLTVChannelReceivesAndroidDefaultCatchupRule() throws {
        let txt = "News,#genre#\nOne,https://example.com/PLTV/channel.m3u8"

        let live = try LivePlaylistParser.parse(txt, into: Live(name: "fixture"))

        XCTAssertEqual(live.groups.first?.channels.first?.catchup, Catchup.pltv)
    }

    func testBrokenGzipEPGReturnsDecompressionError() {
        XCTAssertThrowsError(try EpgParser.parse(Data([0x1f, 0x8b, 0x08]))) { error in
            XCTAssertEqual(error as? EpgParserError, .gzipDecompressionFailed)
        }
    }
}

private struct UnusedLiveHTTPClient: HTTPClient, @unchecked Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        XCTFail("The fixture unexpectedly attempted a network request")
        return HTTPResponse(statusCode: 200, url: request.url, headers: [:], data: Data())
    }
}
