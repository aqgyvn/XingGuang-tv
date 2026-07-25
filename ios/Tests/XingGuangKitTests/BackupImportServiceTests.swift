import Foundation
import XCTest
@testable import XingGuangKit

final class BackupImportServiceTests: XCTestCase {
    func testPlainJSONReturnsValidatedDocument() throws {
        let source = BackupDocument(
            sites: [Site(key: "api", name: "API", api: "https://example.com", type: 1)],
            configs: [ConfigRecord(id: 1, type: 0, url: "https://example.com/config.json")]
        )
        let data = try JSONEncoder().encode(source)

        let result = try BackupImportService().decode(data)

        XCTAssertEqual(result.document, source)
    }

    func testMissingConfigIsRejectedBeforeAValidatedDocumentIsCreated() throws {
        let data = Data(#"{"site":[{"key":"api","name":"API","api":"https://example.com"}]}"#.utf8)

        XCTAssertThrowsError(try BackupImportService().decode(data)) { error in
            XCTAssertEqual(error as? BackupImportError, .requiredCollectionEmpty("config"))
        }
    }

    func testEmptyAndDuplicatePersistenceIdentifiersAreRejected() throws {
        let emptyKey = BackupDocument(
            sites: [Site(key: "  ")],
            configs: [ConfigRecord(url: "https://example.com")]
        )
        XCTAssertThrowsError(try BackupImportService().validate(emptyKey)) { error in
            XCTAssertEqual(error as? BackupImportError, .emptyField(collection: "site", index: 0, field: "key"))
        }

        let duplicate = BackupDocument(
            sites: [Site(key: "same"), Site(key: "same")],
            configs: [ConfigRecord(url: "https://example.com")]
        )
        XCTAssertThrowsError(try BackupImportService().validate(duplicate)) { error in
            XCTAssertEqual(error as? BackupImportError, .duplicateIdentifier(collection: "site", field: "key", value: "same"))
        }
    }

    func testConfigDuplicatePrimaryAndUniquePairAreRejected() throws {
        let duplicateIDs = BackupDocument(configs: [
            ConfigRecord(id: 7, type: 0, url: "https://a.example"),
            ConfigRecord(id: 7, type: 1, url: "https://b.example")
        ])
        XCTAssertThrowsError(try BackupImportService().validate(duplicateIDs)) { error in
            XCTAssertEqual(error as? BackupImportError, .duplicateIdentifier(collection: "config", field: "id", value: "7"))
        }

        let duplicatePair = BackupDocument(configs: [
            ConfigRecord(type: 0, url: "https://a.example"),
            ConfigRecord(type: 0, url: "https://a.example")
        ])
        XCTAssertThrowsError(try BackupImportService().validate(duplicatePair)) { error in
            XCTAssertEqual(error as? BackupImportError, .duplicateIdentifier(collection: "config", field: "type/url", value: "0/https://a.example"))
        }
    }

    func testGzipWithoutDecoderReturnsExplicitUnsupportedError() throws {
        let gzipHeader = Data([0x1f, 0x8b, 0x08, 0x00])

        XCTAssertThrowsError(try BackupImportService(gzipDecompressor: nil).decode(gzipHeader)) { error in
            XCTAssertEqual(error as? BackupImportError, .unsupportedCompression("gzip"))
        }
    }

    func testSystemGzipDecoderRestoresAndroidExport() throws {
        let encoded = "H4sIAAAAAAAEAKtWSs7PS8tMV7KKrlbKTFGyMtRRKqksSFWyMtBRKi3KUbJSyigpKSi20tdPrUjMLchJ1UvOz9WHaNLLKs7PU6qNrQUADIWWwUYAAAA="
        let data = try XCTUnwrap(Data(base64Encoded: encoded))

        let result = try BackupImportService().decode(data)

        XCTAssertEqual(result.document.configs.first?.url, "https://example.com/config.json")
    }

    func testInjectedGzipDecoderCanBeUsedWithoutChangingValidation() throws {
        let source = BackupDocument(configs: [ConfigRecord(url: "https://example.com/config.json")])
        let json = try JSONEncoder().encode(source)
        let compressed = Data([0x1f, 0x8b, 0x08, 0x00])
        let service = BackupImportService(gzipDecompressor: StubGzipDecoder(output: json))

        let result = try service.decode(compressed)

        XCTAssertEqual(result.document, source)
    }

    func testRestoreAppliesValidatedDocumentOnce() throws {
        let source = BackupDocument(configs: [ConfigRecord(url: "https://example.com/config.json")])
        let destination = SpyBackupDestination()

        let result = try BackupImportService().restore(try JSONEncoder().encode(source), to: destination)

        XCTAssertEqual(result.document, source)
        XCTAssertEqual(destination.applyCount, 1)
        XCTAssertEqual(destination.lastBackup?.document, source)
    }

    func testDecompressionFailureIsReportedAndNoPersistenceBoundaryIsCalled() throws {
        let service = BackupImportService(gzipDecompressor: StubGzipDecoder(error: TestError.failed))
        let destination = SpyBackupDestination()

        XCTAssertThrowsError(try service.restore(Data([0x1f, 0x8b]), to: destination)) { error in
            XCTAssertEqual(error as? BackupImportError, .decompressionFailed)
        }
        XCTAssertEqual(destination.applyCount, 0)
    }
}

private struct StubGzipDecoder: BackupGzipDecompressing {
    let output: Data?
    let error: Error?

    init(output: Data) {
        self.output = output
        self.error = nil
    }

    init(error: Error) {
        self.output = nil
        self.error = error
    }

    func decompress(_ data: Data) throws -> Data {
        if let error { throw error }
        return output ?? Data()
    }
}

private final class SpyBackupDestination: BackupDocumentApplying {
    private(set) var applyCount = 0
    private(set) var lastBackup: ValidatedBackupDocument?

    func replaceAll(with backup: ValidatedBackupDocument) throws {
        applyCount += 1
        lastBackup = backup
    }
}

private enum TestError: Error {
    case failed
}
