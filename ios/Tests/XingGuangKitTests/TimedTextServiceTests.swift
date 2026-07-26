import XCTest
@testable import XingGuangKit

final class TimedTextServiceTests: XCTestCase {
    func testParsesSRTAndWebVTTTiming() throws {
        let srt = """
        1
        00:00:01,500 --> 00:00:03,000
        <b>第一行</b>

        2
        00:00:04.000 --> 00:00:05.250
        第二行
        """

        let cues = try TimedTextParser.subtitles(data: Data(srt.utf8), format: "srt")

        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 1.5)
        XCTAssertEqual(cues[0].end, 3)
        XCTAssertEqual(cues[0].text, "第一行")
        XCTAssertEqual(cues[1].text, "第二行")
    }

    func testParsesASSDialogueAndLineBreaks() throws {
        let ass = """
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:02.00,0:00:04.50,Default,,0,0,0,,{\\b1}星光\\N字幕
        """

        let cues = try TimedTextParser.subtitles(data: Data(ass.utf8), format: "ass")

        XCTAssertEqual(cues, [TimedTextCue(id: 0, start: 2, end: 4.5, text: "星光\n字幕")])
    }

    func testParsesBilibiliXMLDanmakuPlacements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <i>
          <d p="1.5,1,25,16777215,0,0,0,0">滚动</d>
          <d p="2.0,5,24,16711680,0,0,0,0">顶部</d>
          <d p="3.0,4,24,65280,0,0,0,0">底部</d>
        </i>
        """

        let cues = try TimedTextParser.danmaku(data: Data(xml.utf8), format: "xml")

        XCTAssertEqual(cues.count, 3)
        XCTAssertEqual(cues[0].placement, .scrolling)
        XCTAssertEqual(cues[1].placement, .top)
        XCTAssertEqual(cues[2].placement, .bottom)
        XCTAssertEqual(cues[1].color, 0xFF0000)
    }

    func testParsesBracketTimedDanmaku() throws {
        let text = """
        [00:01.50]第一条
        [2.75]第二条
        """

        let cues = try TimedTextParser.danmaku(data: Data(text.utf8), format: "txt")

        XCTAssertEqual(cues.map(\.start), [1.5, 2.75])
        XCTAssertEqual(cues.map(\.text), ["第一条", "第二条"])
    }

    func testLoaderForwardsPlaybackHeadersAndCookies() async throws {
        let client = TimedTextHTTPClientStub(data: Data("00:00:01,000 --> 00:00:02,000\n字幕".utf8))
        let loader = TimedTextLoader(client: client)

        _ = try await loader.loadSubtitle(
            SubtitleResource(url: "https://cdn.example/sub.srt", format: "srt"),
            headers: ["Referer": "https://video.example"],
            cookies: ["session": "token"]
        )

        XCTAssertEqual(client.request?.headers["Referer"], "https://video.example")
        XCTAssertEqual(client.request?.cookies["session"], "token")
    }
}

private final class TimedTextHTTPClientStub: HTTPClient, @unchecked Sendable {
    let data: Data
    private(set) var request: HTTPRequest?

    init(data: Data) { self.data = data }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        self.request = request
        return HTTPResponse(statusCode: 200, url: request.url, headers: [:], data: data)
    }
}
