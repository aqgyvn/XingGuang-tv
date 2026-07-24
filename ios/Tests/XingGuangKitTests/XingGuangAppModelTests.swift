import XCTest
@testable import XingGuangKit

@MainActor
final class XingGuangAppModelTests: XCTestCase {
    func testValidConfigurationIsPersisted() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "https://example.com/vod.json"
        model.liveConfigURL = "file:///var/mobile/live.json"

        model.saveConfiguration()

        XCTAssertEqual(model.configurationSaveState, .saved)
        XCTAssertEqual(defaults.string(forKey: "ios.vodConfigURL"), "https://example.com/vod.json")
        XCTAssertEqual(defaults.string(forKey: "ios.liveConfigURL"), "file:///var/mobile/live.json")
    }

    func testInvalidConfigurationIsRejected() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        model.vodConfigURL = "not a URL"

        model.saveConfiguration()

        XCTAssertEqual(model.configurationSaveState, .invalid)
        XCTAssertNil(defaults.string(forKey: "ios.vodConfigURL"))
    }

    func testCategorySelectionUpdatesPublishedState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = XingGuangAppModel(defaults: defaults)
        let category = model.categories[2]

        model.selectCategory(category)

        XCTAssertEqual(model.selectedCategory, category)
    }

    func testLatestSiteLoadWinsAfterRapidSwitch() async {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = Site(key: "first", name: "第一来源", api: "https://first.example", type: 1)
        let second = Site(key: "second", name: "第二来源", api: "https://second.example", type: 1)
        let repository = DelayedVodRepository()
        let model = XingGuangAppModel(selectedSite: first, defaults: defaults, repository: repository)

        model.selectSite(second)
        model.selectSite(first)
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let items) = model.catalogState else {
            return XCTFail("Expected the latest source catalog")
        }
        XCTAssertEqual(items.first?.vodName, "第一来源影片")
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "XingGuangAppModelTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}

private final class DelayedVodRepository: VodRepository, @unchecked Sendable {
    func loadConfig(from url: URL) async throws -> VodConfigDocument { VodConfigDocument() }

    func home(site: Site, includeFilters: Bool) async throws -> VodResult {
        if site.key == "second" {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return VodResult(list: [Vod(vodID: site.key, vodName: "\(site.name)影片")])
    }

    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult {
        VodResult()
    }

    func search(site: Site, keyword: String, page: Int) async throws -> VodResult { VodResult() }
    func detail(site: Site, vodID: String) async throws -> VodResult { VodResult() }
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest {
        PlaybackRequest(url: episodeURL)
    }
}
