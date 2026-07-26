import Foundation

public final class ClosurePlayerEngineFactory: PlayerEngineFactory, @unchecked Sendable {
    private let mpvBuilder: () -> PlayerEngine
    private let mdkBuilder: () -> PlayerEngine
    private let avPlayerBuilder: () -> PlayerEngine

    public init(
        mpv: @escaping () -> PlayerEngine,
        mdk: @escaping () -> PlayerEngine,
        avPlayer: @escaping () -> PlayerEngine
    ) {
        self.mpvBuilder = mpv
        self.mdkBuilder = mdk
        self.avPlayerBuilder = avPlayer
    }

    public func makePlayer(preference: PlayerEnginePreference) -> PlayerEngine {
        switch preference {
        case .mpv: return mpvBuilder()
        case .mdk: return mdkBuilder()
        case .avPlayer: return avPlayerBuilder()
        }
    }
}
