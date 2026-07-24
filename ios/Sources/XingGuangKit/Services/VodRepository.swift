import Foundation
import Combine
import UIKit

public protocol VodRepository {
    func loadConfig(from url: URL) async throws -> VodConfigDocument
    func home(site: Site, includeFilters: Bool) async throws -> VodResult
    func category(site: Site, typeID: String, page: Int, filters: [String: String]) async throws -> VodResult
    func search(site: Site, keyword: String, page: Int) async throws -> VodResult
    func detail(site: Site, vodID: String) async throws -> VodResult
    func resolvePlayback(site: Site, flag: String, episodeURL: String) async throws -> PlaybackRequest
}

public enum PlayerState: Equatable {
    case idle
    case loading
    case ready(duration: TimeInterval)
    case playing
    case paused
    case ended
    case failed(PlayerFailure)
}

public enum PlayerFailureCategory: String, Equatable {
    case network
    case authentication
    case format
    case decoding
    case drm
    case unknown
}

public struct PlayerFailure: Error, Equatable, LocalizedError {
    public var category: PlayerFailureCategory
    public var message: String

    public init(category: PlayerFailureCategory, message: String) {
        self.category = category
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum PlayerEngineKind: String, Equatable {
    case avPlayer
    case vlc
}

public enum PlayerCapability: String, Hashable {
    case airPlay
    case pictureInPicture
    case backgroundAudio
    case externalSubtitles
    case trackSelection
}

public struct PlayerTime: Equatable {
    public var position: TimeInterval
    public var duration: TimeInterval
    public var buffered: TimeInterval

    public init(position: TimeInterval = 0, duration: TimeInterval = 0, buffered: TimeInterval = 0) {
        self.position = position
        self.duration = duration
        self.buffered = buffered
    }
}

public struct PlayerTrack: Equatable, Identifiable {
    public enum Kind: String, Equatable {
        case audio
        case subtitle
        case video
    }

    public var id: String
    public var kind: Kind
    public var name: String
    public var language: String

    public init(id: String, kind: Kind, name: String, language: String = "") {
        self.id = id
        self.kind = kind
        self.name = name
        self.language = language
    }
}

public protocol PlayerEngine: AnyObject {
    var kind: PlayerEngineKind { get }
    var capabilities: Set<PlayerCapability> { get }
    var state: PlayerState { get }
    var tracks: [PlayerTrack] { get }
    var time: PlayerTime { get }
    var statePublisher: AnyPublisher<PlayerState, Never> { get }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { get }
    var timePublisher: AnyPublisher<PlayerTime, Never> { get }

    func load(_ request: PlaybackRequest)
    func play()
    func pause()
    func seek(to position: TimeInterval)
    func setRate(_ rate: Float)
    func select(track: PlayerTrack?)
    func stop()
    func makePlayerViewController() -> UIViewController
    @discardableResult func startPictureInPicture() -> Bool
    func release()
}

public protocol PlayerEngineFactory: Sendable {
    func makePlayer(preference: PlayerEnginePreference) -> PlayerEngine
}
