import Foundation

public final class CacheManagementService: @unchecked Sendable {
    private let directory: URL
    private let urlCache: URLCache

    public init(directory: URL? = nil, urlCache: URLCache = .shared) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.urlCache = urlCache
    }

    public func size() async -> Int64 {
        await Task.detached(priority: .utility) { [directory] in
            Self.directorySize(directory)
        }.value
    }

    public func clear() async throws {
        urlCache.removeAllCachedResponses()
        try await Task.detached(priority: .utility) { [directory] in
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: directory.path) else { return }
            for item in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                try fileManager.removeItem(at: item)
            }
        }.value
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
