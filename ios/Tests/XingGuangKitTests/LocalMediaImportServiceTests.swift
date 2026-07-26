import Foundation
import XCTest
@testable import XingGuangKit

final class LocalMediaImportServiceTests: XCTestCase {
    func testCopiesSupportedMediaIntoPrivateCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("sample.mkv")
        let data = Data([0x1A, 0x45, 0xDF, 0xA3])
        try data.write(to: source)
        let service = LocalMediaImportService(directory: root.appendingPathComponent("imports"))

        let imported = try await service.importFile(at: source)

        XCTAssertEqual(imported.displayName, "sample.mkv")
        XCTAssertEqual(imported.url.pathExtension, "mkv")
        XCTAssertEqual(try Data(contentsOf: imported.url), data)
    }

    func testRejectsUnsupportedFileWithoutCreatingCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("notes.txt")
        try Data("not media".utf8).write(to: source)
        let service = LocalMediaImportService(directory: root.appendingPathComponent("imports"))

        do {
            _ = try await service.importFile(at: source)
            XCTFail("Expected unsupported format")
        } catch {
            XCTAssertEqual(error as? LocalMediaImportError, .unsupportedFormat)
        }
    }
}
