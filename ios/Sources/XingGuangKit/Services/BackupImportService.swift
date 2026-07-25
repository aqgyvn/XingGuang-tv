import Foundation

/// The payload formats emitted by the Android application.
public enum BackupPayloadFormat: Equatable {
    case automatic
    case json
    case androidGzip
}

/// Supplies gzip decoding while keeping the importer testable and allowing a
/// consumer to replace the system zlib implementation when necessary.
public protocol BackupGzipDecompressing {
    func decompress(_ data: Data) throws -> Data
}

/// A document that has passed all import checks.  Its initializer is private to
/// this file so a persistence layer cannot accidentally bypass validation.
public struct ValidatedBackupDocument: Equatable {
    public let document: BackupDocument

    fileprivate init(document: BackupDocument) {
        self.document = document
    }
}

/// The smallest persistence boundary needed for an atomic restore.  An
/// `AppDatabase` implementation can apply this already-validated value inside
/// one transaction; the importer itself never writes persistence.
public protocol BackupDocumentApplying {
    func replaceAll(with backup: ValidatedBackupDocument) throws
}

public enum BackupImportError: Error, Equatable, LocalizedError {
    case emptyPayload
    case invalidJSON
    case unsupportedCompression(String)
    case decompressionFailed
    case requiredCollectionEmpty(String)
    case emptyField(collection: String, index: Int, field: String)
    case duplicateIdentifier(collection: String, field: String, value: String)

    public var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return "备份文件为空"
        case .invalidJSON:
            return "备份文件不是有效的 JSON"
        case .unsupportedCompression(let name):
            return "暂不支持的备份压缩格式：\(name)"
        case .decompressionFailed:
            return "备份文件解压失败"
        case .requiredCollectionEmpty(let collection):
            return "备份缺少可恢复的\(collection)配置"
        case .emptyField(let collection, let index, let field):
            return "备份的\(collection)[\(index)]缺少\(field)"
        case .duplicateIdentifier(let collection, let field, let value):
            return "备份的\(collection)存在重复\(field)：\(value)"
        }
    }
}

/// Decodes and validates Android backup payloads without touching a database.
public struct BackupImportService {
    private let gzipDecompressor: (any BackupGzipDecompressing)?

    public init(gzipDecompressor: (any BackupGzipDecompressing)? = SystemGzipDecompressor()) {
        self.gzipDecompressor = gzipDecompressor
    }

    /// Decode a JSON or `.bk.gz` payload. The default decoder uses the zlib
    /// shipped with iOS 15; passing `nil` produces an explicit unsupported
    /// compression error instead of treating compressed bytes as JSON.
    public func decode(
        _ data: Data,
        format: BackupPayloadFormat = .automatic
    ) throws -> ValidatedBackupDocument {
        guard !data.isEmpty else { throw BackupImportError.emptyPayload }

        let jsonData: Data
        switch format {
        case .json:
            jsonData = data
        case .automatic:
            jsonData = try payloadData(data, isGzip: isGzip(data))
        case .androidGzip:
            jsonData = try payloadData(data, isGzip: true)
        }

        guard !jsonData.isEmpty else { throw BackupImportError.emptyPayload }
        let document: BackupDocument
        do {
            document = try JSONDecoder().decode(BackupDocument.self, from: jsonData)
        } catch {
            throw BackupImportError.invalidJSON
        }
        return try validate(document)
    }

    /// Applies a payload only after decoding and validation have both
    /// succeeded. The destination receives no call for an invalid backup.
    @discardableResult
    public func restore(
        _ data: Data,
        to destination: any BackupDocumentApplying,
        format: BackupPayloadFormat = .automatic
    ) throws -> ValidatedBackupDocument {
        let backup = try decode(data, format: format)
        try destination.replaceAll(with: backup)
        return backup
    }

    /// Validate an already-decoded document before passing it to persistence.
    public func validate(_ document: BackupDocument) throws -> ValidatedBackupDocument {
        // Android refuses to restore a backup without at least one config.
        guard !document.configs.isEmpty else {
            throw BackupImportError.requiredCollectionEmpty("config")
        }

        try validateUnique(document.sites, collection: "site", field: "key", identifier: \.key)
        try validateUnique(document.lives, collection: "live", field: "name", identifier: \.name)
        try validateUnique(document.keeps, collection: "keep", field: "key", identifier: \.key)
        try validateUnique(document.histories, collection: "history", field: "key", identifier: \.key)

        var configIDs = Set<Int>()
        var configKeys = Set<ConfigIdentity>()
        for (index, config) in document.configs.enumerated() {
            try requireNonEmpty(config.url, collection: "config", index: index, field: "url")
            // Room auto-generates id 0.  It is therefore valid for several
            // newly-created records to carry that value in an export.
            if config.id != 0 && !configIDs.insert(config.id).inserted {
                throw BackupImportError.duplicateIdentifier(
                    collection: "config",
                    field: "id",
                    value: String(config.id)
                )
            }
            let identity = ConfigIdentity(type: config.type, url: config.url)
            if !configKeys.insert(identity).inserted {
                throw BackupImportError.duplicateIdentifier(
                    collection: "config",
                    field: "type/url",
                    value: "\(config.type)/\(config.url)"
                )
            }
        }

        for (key, _) in document.preferences {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackupImportError.emptyField(collection: "prefers", index: 0, field: "key")
            }
        }

        return ValidatedBackupDocument(document: document)
    }

    private func payloadData(_ data: Data, isGzip: Bool) throws -> Data {
        guard isGzip else { return data }
        guard let gzipDecompressor else {
            throw BackupImportError.unsupportedCompression("gzip")
        }
        do {
            return try gzipDecompressor.decompress(data)
        } catch {
            throw BackupImportError.decompressionFailed
        }
    }

    private func isGzip(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x1f && data[data.index(after: data.startIndex)] == 0x8b
    }

    private func validateUnique<Value>(
        _ values: [Value],
        collection: String,
        field: String,
        identifier: (Value) -> String
    ) throws {
        var identifiers = Set<String>()
        for (index, value) in values.enumerated() {
            let id = identifier(value)
            try requireNonEmpty(id, collection: collection, index: index, field: field)
            if !identifiers.insert(id).inserted {
                throw BackupImportError.duplicateIdentifier(collection: collection, field: field, value: id)
            }
        }
    }

    private func requireNonEmpty(
        _ value: String,
        collection: String,
        index: Int,
        field: String
    ) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BackupImportError.emptyField(collection: collection, index: index, field: field)
        }
    }
}

private struct ConfigIdentity: Hashable {
    let type: Int
    let url: String
}
