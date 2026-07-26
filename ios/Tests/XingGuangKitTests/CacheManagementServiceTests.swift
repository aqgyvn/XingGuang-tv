import Foundation
import XCTest
@testable import XingGuangKit

final class CacheManagementServiceTests: XCTestCase {
    func testCalculatesNestedCacheSize() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("ImportedMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_024).write(to: nested.appendingPathComponent("video.bin"))
        try Data(repeating: 2, count: 512).write(to: root.appendingPathComponent("response.cache"))

        let size = await CacheManagementService(directory: root, urlCache: URLCache(memoryCapacity: 0, diskCapacity: 0)).size()

        XCTAssertEqual(size, 1_536)
    }

    func testClearsOnlyConfiguredCacheDirectory() async throws {
        let container = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: container) }
        let cache = container.appendingPathComponent("Caches", isDirectory: true)
        let persistent = container.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: persistent, withIntermediateDirectories: true)
        try Data([1]).write(to: cache.appendingPathComponent("temporary.bin"))
        let database = persistent.appendingPathComponent("xingguang.sqlite")
        try Data([2]).write(to: database)

        let service = CacheManagementService(directory: cache, urlCache: URLCache(memoryCapacity: 0, diskCapacity: 0))
        try await service.clear()

        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: cache.path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: database), Data([2]))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
