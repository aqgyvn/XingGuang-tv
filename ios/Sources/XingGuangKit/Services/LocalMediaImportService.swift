import Foundation
import UniformTypeIdentifiers

public struct LocalMediaFile: Equatable, Identifiable {
    public let url: URL
    public let displayName: String

    public var id: String { url.absoluteString }

    public init(url: URL, displayName: String) {
        self.url = url
        self.displayName = displayName
    }
}

public enum LocalMediaImportError: Error, Equatable, LocalizedError {
    case unsupportedFormat
    case unreadableFile

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持此本地媒体格式"
        case .unreadableFile: return "无法读取所选媒体文件"
        }
    }
}

public final class LocalMediaImportService: @unchecked Sendable {
    public static let supportedExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "flv", "webm", "avi", "ts", "m2ts",
        "mp3", "m4a", "aac", "flac", "ogg", "oga", "wav"
    ]

    public static var contentTypes: [UTType] {
        supportedExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    private let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedMedia", isDirectory: true)
    }

    public func importFile(at sourceURL: URL) async throws -> LocalMediaFile {
        try await Task.detached(priority: .userInitiated) { [directory] in
            let fileManager = FileManager.default
            let fileExtension = sourceURL.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(fileExtension) else {
                throw LocalMediaImportError.unsupportedFormat
            }
            guard (try? sourceURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                throw LocalMediaImportError.unreadableFile
            }

            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
                return LocalMediaFile(url: destination, displayName: sourceURL.lastPathComponent)
            } catch {
                try? fileManager.removeItem(at: destination)
                throw LocalMediaImportError.unreadableFile
            }
        }.value
    }
}
