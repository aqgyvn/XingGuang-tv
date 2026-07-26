import Foundation

public enum ConfigurationKind: String, Equatable, Identifiable {
    case vod
    case live

    public var id: String { rawValue }
}

public enum ConfigurationImportError: Error, Equatable, LocalizedError {
    case emptyFile
    case fileTooLarge
    case invalidVodConfiguration
    case invalidLiveConfiguration
    case invalidScannedAddress

    public var errorDescription: String? {
        switch self {
        case .emptyFile: return "配置文件为空"
        case .fileTooLarge: return "配置文件超过 10 MB"
        case .invalidVodConfiguration: return "点播配置文件格式无效"
        case .invalidLiveConfiguration: return "直播配置文件格式无效"
        case .invalidScannedAddress: return "二维码不是有效的 HTTP(S) 配置地址"
        }
    }
}

public struct ConfigurationImportService {
    private let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedConfigurations", isDirectory: true)
    }

    public func importFile(at sourceURL: URL, kind: ConfigurationKind) throws -> URL {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw ConfigurationImportError.emptyFile }
        guard data.count <= 10 * 1_024 * 1_024 else { throw ConfigurationImportError.fileTooLarge }
        try validate(data, sourceURL: sourceURL, kind: kind)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? (kind == .vod ? "json" : "txt") : sourceURL.pathExtension
        let destination = directory.appendingPathComponent("\(kind.rawValue)-config.\(fileExtension)")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func scannedAddress(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
            throw ConfigurationImportError.invalidScannedAddress
        }
        return url
    }

    private func validate(_ data: Data, sourceURL: URL, kind: ConfigurationKind) throws {
        switch kind {
        case .vod:
            guard let document = try? JSONDecoder().decode(VodConfigDocument.self, from: data),
                  document.sites.contains(where: { !$0.key.isEmpty && !$0.api.isEmpty }) else {
                throw ConfigurationImportError.invalidVodConfiguration
            }
        case .live:
            guard let live = try? LivePlaylistParser.parse(data, into: Live(name: sourceURL.deletingPathExtension().lastPathComponent), sourceURL: sourceURL),
                  live.groups.contains(where: { !$0.channels.isEmpty }) else {
                throw ConfigurationImportError.invalidLiveConfiguration
            }
        }
    }
}
