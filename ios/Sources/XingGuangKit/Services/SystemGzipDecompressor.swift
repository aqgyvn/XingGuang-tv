import Foundation
import CGzip

/// Uses the system zlib shipped with iOS to decode Android .bk.gz exports.
public struct SystemGzipDecompressor: BackupGzipDecompressing, Sendable {
    public init() {}

    public func decompress(_ data: Data) throws -> Data {
        var output: UnsafeMutablePointer<UInt8>?
        var outputLength = 0
        let status = data.withUnsafeBytes { bytes -> Int32 in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return Int32(xg_gzip_decompress(baseAddress, data.count, &output, &outputLength))
        }
        guard status == 0, let output else { throw BackupImportError.decompressionFailed }
        defer { xg_gzip_free(output) }
        return Data(bytes: output, count: outputLength)
    }
}
