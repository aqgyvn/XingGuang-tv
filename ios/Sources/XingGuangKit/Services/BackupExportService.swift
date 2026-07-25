import Foundation

public enum BackupExportFormat: Equatable {
    case json
    case androidGzip
}

public protocol BackupGzipCompressing {
    func compress(_ data: Data) throws -> Data
}

public enum BackupExportError: Error, Equatable, LocalizedError {
    case unsupportedCompression(String)
    case compressionFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedCompression(let name):
            return "Unsupported backup compression: \(name)"
        case .compressionFailed:
            return "Backup compression failed"
        }
    }
}

public struct BackupExportArtifact: Equatable {
    public let data: Data
    public let suggestedFileName: String

    public init(data: Data, suggestedFileName: String) {
        self.data = data
        self.suggestedFileName = suggestedFileName
    }
}

/// Encodes an Android-compatible backup after applying the same validation
/// used by restore. Invalid data never reaches the compressor.
public struct BackupExportService {
    private let gzipCompressor: (any BackupGzipCompressing)?

    public init(gzipCompressor: (any BackupGzipCompressing)? = SystemGzipCompressor()) {
        self.gzipCompressor = gzipCompressor
    }

    public func encode(
        _ document: BackupDocument,
        format: BackupExportFormat = .androidGzip
    ) throws -> Data {
        let validated = try BackupImportService(gzipDecompressor: nil).validate(document)
        let jsonData = try JSONEncoder().encode(validated.document)

        switch format {
        case .json:
            return jsonData
        case .androidGzip:
            guard let gzipCompressor else {
                throw BackupExportError.unsupportedCompression("gzip")
            }
            do {
                return try gzipCompressor.compress(jsonData)
            } catch let error as BackupExportError {
                throw error
            } catch {
                throw BackupExportError.compressionFailed
            }
        }
    }

    public func artifact(
        for document: BackupDocument,
        format: BackupExportFormat = .androidGzip,
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) throws -> BackupExportArtifact {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let suffix = format == .androidGzip ? ".bk.gz" : ".bk"
        return BackupExportArtifact(
            data: try encode(document, format: format),
            suggestedFileName: "tv-\(formatter.string(from: date))\(suffix)"
        )
    }
}
