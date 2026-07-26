import Foundation
import XCTest
@testable import XingGuangKit

final class ConfigurationImportServiceTests: XCTestCase {
    func testImportsValidatedVodAndLiveFilesIntoPrivateDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("imports", isDirectory: true)
        let service = ConfigurationImportService(directory: destination)
        let vodSource = root.appendingPathComponent("vod.json")
        let liveSource = root.appendingPathComponent("live.m3u")
        try Data(#"{"sites":[{"key":"fixture","api":"https://api.example","type":1}]}"#.utf8).write(to: vodSource)
        try Data("#EXTM3U\n#EXTINF:-1,News\nhttps://cdn.example/live.m3u8\n".utf8).write(to: liveSource)

        let vodURL = try service.importFile(at: vodSource, kind: .vod)
        let liveURL = try service.importFile(at: liveSource, kind: .live)

        XCTAssertTrue(FileManager.default.fileExists(atPath: vodURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: liveURL.path))
        XCTAssertEqual(try Data(contentsOf: vodURL), try Data(contentsOf: vodSource))
        XCTAssertEqual(try Data(contentsOf: liveURL), try Data(contentsOf: liveSource))
    }

    func testInvalidFileDoesNotReplacePreviouslyImportedConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = ConfigurationImportService(directory: root.appendingPathComponent("imports"))
        let valid = root.appendingPathComponent("valid.json")
        let invalid = root.appendingPathComponent("invalid.json")
        let validData = Data(#"{"sites":[{"key":"fixture","api":"https://api.example","type":1}]}"#.utf8)
        try validData.write(to: valid)
        try Data("{}".utf8).write(to: invalid)
        let imported = try service.importFile(at: valid, kind: .vod)

        XCTAssertThrowsError(try service.importFile(at: invalid, kind: .vod))
        XCTAssertEqual(try Data(contentsOf: imported), validData)
    }

    func testScannedAddressAcceptsOnlyHTTPAndHTTPS() throws {
        let service = ConfigurationImportService(directory: FileManager.default.temporaryDirectory)

        XCTAssertEqual(try service.scannedAddress(" https://example.com/config.json \n").absoluteString, "https://example.com/config.json")
        XCTAssertThrowsError(try service.scannedAddress("file:///private/config.json"))
        XCTAssertThrowsError(try service.scannedAddress("not a url"))
    }
}
