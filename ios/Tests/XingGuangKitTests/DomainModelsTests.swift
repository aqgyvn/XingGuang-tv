import XCTest
@testable import XingGuangKit

final class DomainModelsTests: XCTestCase {
    func testPreviewConfigDecodesAndroidCompatibleFields() throws {
        let config = PreviewFixtures.config

        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites[0].key, "preview")
        XCTAssertEqual(config.sites[0].type, 1)
        XCTAssertEqual(config.sites[0].searchable, 1)
        XCTAssertEqual(config.sites[0].changeable, 1)
        XCTAssertEqual(config.lives.first?.groups.first?.channels.count, 2)
    }

    func testConfigDecodesAndroidHeaderAdsAndDoHFields() throws {
        let data = Data(#"{"headers":[{"host":"api.example","header":{"Referer":"https://source.example/"}}],"ads":["ads.example"],"doh":[{"name":"Fixture","url":"https://doh.example/dns-query","ips":["1.1.1.1"]}]}"#.utf8)

        let config = try JSONDecoder().decode(VodConfigDocument.self, from: data)

        XCTAssertEqual(config.headers.first?.host, "api.example")
        XCTAssertEqual(config.headers.first?.header["Referer"], "https://source.example/")
        XCTAssertEqual(config.ads, ["ads.example"])
        XCTAssertEqual(config.doh.first?.ips, ["1.1.1.1"])
    }

    func testSiteUsesAndroidDefaultsWhenOptionalFieldsAreMissing() throws {
        let data = Data(#"{"key":"minimal","name":"Minimal","api":"https://example.com"}"#.utf8)
        let site = try JSONDecoder().decode(Site.self, from: data)

        XCTAssertEqual(site.type, 0)
        XCTAssertEqual(site.searchable, 1)
        XCTAssertEqual(site.changeable, 1)
        XCTAssertEqual(site.quickSearch, 1)
        XCTAssertTrue(site.categories.isEmpty)
        XCTAssertTrue(site.header.isEmpty)
    }

    func testVodUsesEmptyStringsWhenOptionalFieldsAreMissing() throws {
        let vod = try JSONDecoder().decode(Vod.self, from: Data(#"{"vod_id":"7","vod_name":"Minimal"}"#.utf8))

        XCTAssertEqual(vod.vodID, "7")
        XCTAssertEqual(vod.vodName, "Minimal")
        XCTAssertEqual(vod.vodRemarks, "")
        XCTAssertEqual(vod.vodPlayURL, "")
    }

    func testVodAndClassAcceptNumericIdentifiers() throws {
        let vod = try JSONDecoder().decode(Vod.self, from: Data(#"{"vod_id":7,"vod_name":"Numeric"}"#.utf8))
        let category = try JSONDecoder().decode(VodClass.self, from: Data(#"{"type_id":12,"type_name":"电影"}"#.utf8))

        XCTAssertEqual(vod.vodID, "7")
        XCTAssertEqual(category.typeID, "12")
    }

    func testBackupDefaultsMissingCollectionsToEmpty() throws {
        let backup = try JSONDecoder().decode(BackupDocument.self, from: Data("{}".utf8))

        XCTAssertTrue(backup.sites.isEmpty)
        XCTAssertTrue(backup.lives.isEmpty)
        XCTAssertTrue(backup.keeps.isEmpty)
        XCTAssertTrue(backup.configs.isEmpty)
        XCTAssertTrue(backup.histories.isEmpty)
        XCTAssertTrue(backup.preferences.isEmpty)
    }

    func testHistoryDefaultsMatchAndroidUnsetPlaybackValues() throws {
        let history = try JSONDecoder().decode(History.self, from: Data(#"{"key":"site@@@vod"}"#.utf8))

        XCTAssertEqual(history.speed, 1)
        XCTAssertEqual(history.scale, -1)
        XCTAssertEqual(history.position, -1)
        XCTAssertEqual(history.duration, -1)
    }

    func testVodFilterUsesAndroidInitAndValueShape() throws {
        let data = Data(#"{"key":"area","name":"地区","init":"all","value":[{"n":"全部","v":"all"},{"n":"大陆","v":"cn"}]}"#.utf8)

        let filter = try JSONDecoder().decode(VodFilter.self, from: data)

        XCTAssertEqual(filter.initialValue, "all")
        XCTAssertEqual(filter.values.map(\.value), ["all", "cn"])
    }

    func testVodResultAcceptsURLSelectionObject() throws {
        let data = Data(#"{"url":{"values":[{"n":"线路一","v":"https://a.example/video"},{"n":"线路二","v":"https://b.example/video"}],"position":1}}"#.utf8)

        let result = try JSONDecoder().decode(VodResult.self, from: data)

        XCTAssertEqual(result.url, "https://b.example/video")
    }

    func testVodResultAcceptsAndroidURLPairs() throws {
        let result = try JSONDecoder().decode(VodResult.self, from: Data(#"{"url":["线路一","https://a.example/video","线路二","https://b.example/video"]}"#.utf8))

        XCTAssertEqual(result.url, "https://a.example/video")
    }

    func testVodResultEncodesSubtitlesWithAndroidFieldName() throws {
        let result = VodResult(
            subtitles: [SubtitleResource(url: "https://a.example/subtitle.vtt", name: "中文")],
            danmaku: [DanmakuResource(url: "https://a.example/danmaku.xml", name: "弹幕")]
        )
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any]
        let subtitles = object?["subs"] as? [[String: String]]
        let danmaku = object?["danmaku"] as? [[String: String]]

        XCTAssertEqual(subtitles?.first?["url"], "https://a.example/subtitle.vtt")
        XCTAssertEqual(danmaku?.first?["url"], "https://a.example/danmaku.xml")
        XCTAssertNil(object?["subtitles"])
    }

    func testDanmakuResourceAcceptsAndroidStringForm() throws {
        let result = try JSONDecoder().decode(VodResult.self, from: Data(#"{"danmaku":["https://a.example/danmaku.xml"]}"#.utf8))

        XCTAssertEqual(result.danmaku.first?.url, "https://a.example/danmaku.xml")
    }
}
