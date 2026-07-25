import Foundation
import XCTest
@testable import XingGuangKit

final class BackupExportServiceTests: XCTestCase {
    func testJSONExportCanBeImportedWithoutLosingFields() throws {
        let source = makeDocument()

        let data = try BackupExportService().encode(source, format: .json)
        let restored = try BackupImportService().decode(data, format: .json)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(restored.document, source)
        XCTAssertEqual(
            Set(object.keys),
            Set(["site", "live", "keep", "config", "history", "prefers"])
        )
    }

    func testSystemGzipExportCanBeImportedAsAndroidBackup() throws {
        let source = makeDocument()

        let data = try BackupExportService().encode(source)
        let restored = try BackupImportService().decode(data, format: .androidGzip)

        XCTAssertEqual(Array(data.prefix(2)), [0x1f, 0x8b])
        XCTAssertEqual(restored.document, source)
    }

    func testInvalidDocumentIsRejectedBeforeCompression() throws {
        let compressor = SpyGzipCompressor()
        let service = BackupExportService(gzipCompressor: compressor)

        XCTAssertThrowsError(try service.encode(BackupDocument())) { error in
            XCTAssertEqual(error as? BackupImportError, .requiredCollectionEmpty("config"))
        }
        XCTAssertEqual(compressor.callCount, 0)
    }

    func testCompressionFailureUsesExportError() throws {
        let service = BackupExportService(gzipCompressor: FailingGzipCompressor())

        XCTAssertThrowsError(try service.encode(makeDocument())) { error in
            XCTAssertEqual(error as? BackupExportError, .compressionFailed)
        }
    }

    func testMissingGzipCompressorUsesExplicitUnsupportedError() throws {
        let service = BackupExportService(gzipCompressor: nil)

        XCTAssertThrowsError(try service.encode(makeDocument())) { error in
            XCTAssertEqual(error as? BackupExportError, .unsupportedCompression("gzip"))
        }
    }

    func testArtifactUsesAndroidFileName() throws {
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-07-25T12:00:00Z")
        )

        let artifact = try BackupExportService().artifact(
            for: makeDocument(),
            date: date,
            timeZone: TimeZone(secondsFromGMT: 0) ?? .current
        )

        XCTAssertEqual(artifact.suggestedFileName, "tv-2026-07-25.bk.gz")
    }

    private func makeDocument() -> BackupDocument {
        BackupDocument(
            sites: [Site(key: "api", name: "API", api: "https://example.com/api.php", type: 1)],
            lives: [Live(name: "Live", url: "https://example.com/live.m3u")],
            keeps: [Keep(key: "api-1", siteName: "API", vodName: "Example")],
            configs: [ConfigRecord(id: 1, type: 0, url: "https://example.com/config.json")],
            histories: [History(key: "api-1", vodName: "Example")],
            preferences: ["player": .string("auto"), "incognito": .bool(false)]
        )
    }
}

private final class SpyGzipCompressor: BackupGzipCompressing {
    private(set) var callCount = 0

    func compress(_ data: Data) throws -> Data {
        callCount += 1
        return data
    }
}

private struct FailingGzipCompressor: BackupGzipCompressing {
    func compress(_ data: Data) throws -> Data {
        throw TestError.failed
    }
}

private enum TestError: Error {
    case failed
}
