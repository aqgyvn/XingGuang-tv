import Foundation
import CGzip

/// Uses the system zlib shipped with iOS to create Android-compatible gzip backups.
public struct SystemGzipCompressor: BackupGzipCompressing, Sendable {
    public init() {}

    public func compress(_ data: Data) throws -> Data {
        var output: UnsafeMutablePointer<UInt8>?
        var outputLength = 0
        let status = data.withUnsafeBytes { bytes -> Int32 in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return Int32(xg_gzip_compress(baseAddress, data.count, &output, &outputLength))
        }
        guard status == 0, let output else { throw BackupExportError.compressionFailed }
        defer { xg_gzip_free(output) }
        return Data(bytes: output, count: outputLength)
    }
}
