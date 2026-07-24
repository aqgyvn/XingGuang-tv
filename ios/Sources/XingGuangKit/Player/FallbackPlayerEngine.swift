import Foundation
import Combine
import UIKit

public final class ClosurePlayerEngineFactory: PlayerEngineFactory, @unchecked Sendable {
    private let avPlayerBuilder: () -> PlayerEngine
    private let vlcBuilder: () -> PlayerEngine

    public init(avPlayer: @escaping () -> PlayerEngine, vlc: @escaping () -> PlayerEngine) {
        self.avPlayerBuilder = avPlayer
        self.vlcBuilder = vlc
    }

    public func makePlayer(preference: PlayerEnginePreference) -> PlayerEngine {
        FallbackPlayerEngine(preference: preference, avPlayer: avPlayerBuilder(), vlc: vlcBuilder())
    }
}

public final class FallbackPlayerEngine: PlayerEngine {
    public var kind: PlayerEngineKind { active.kind }
    public var capabilities: Set<PlayerCapability> { active.capabilities }
    public var state: PlayerState { stateSubject.value }
    public var tracks: [PlayerTrack] { tracksSubject.value }
    public var time: PlayerTime { timeSubject.value }
    public var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    public var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { tracksSubject.eraseToAnyPublisher() }
    public var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    private let preference: PlayerEnginePreference
    private let avPlayer: PlayerEngine
    private let vlc: PlayerEngine
    private let host = PlayerHostViewController()
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let tracksSubject = CurrentValueSubject<[PlayerTrack], Never>([])
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())
    private var active: PlayerEngine
    private var request: PlaybackRequest?
    private var didFallback = false
    private var allowsFallback = false
    private var subscriptions: Set<AnyCancellable> = []

    public init(preference: PlayerEnginePreference, avPlayer: PlayerEngine, vlc: PlayerEngine) {
        self.preference = preference
        self.avPlayer = avPlayer
        self.vlc = vlc
        self.active = preference == .vlc ? vlc : avPlayer
        bindActiveEngine()
    }

    public func load(_ request: PlaybackRequest) {
        self.request = request
        didFallback = false
        let selected = selectEngine(for: request)
        let requested = request.enginePreference == .automatic ? preference : request.enginePreference
        allowsFallback = requested == .automatic
        switchEngine(to: selected)
        active.load(request)
    }

    public func play() { active.play() }
    public func pause() { active.pause() }
    public func seek(to position: TimeInterval) { active.seek(to: position) }
    public func setRate(_ rate: Float) { active.setRate(rate) }
    public func select(track: PlayerTrack?) { active.select(track: track) }
    public func stop() { active.stop() }
    public func makePlayerViewController() -> UIViewController {
        host.show(active.makePlayerViewController())
        return host
    }
    public func startPictureInPicture() -> Bool { active.startPictureInPicture() }

    public func release() {
        subscriptions.removeAll()
        avPlayer.release()
        vlc.release()
    }

    private func selectEngine(for request: PlaybackRequest) -> PlayerEngine {
        let requested = request.enginePreference == .automatic ? preference : request.enginePreference
        if requested == .avPlayer { return avPlayer }
        if requested == .vlc { return vlc }
        let scheme = URL(string: request.url)?.scheme?.lowercased() ?? ""
        let path = URL(string: request.url)?.pathExtension.lowercased() ?? ""
        let vlcSchemes: Set<String> = ["rtsp", "rtmp", "rtp"]
        let vlcExtensions: Set<String> = ["mkv", "flv", "webm", "avi", "mpd"]
        return vlcSchemes.contains(scheme) || vlcExtensions.contains(path) ? vlc : avPlayer
    }

    private func switchEngine(to engine: PlayerEngine) {
        guard active !== engine else {
            host.show(engine.makePlayerViewController())
            return
        }
        active.stop()
        active = engine
        bindActiveEngine()
        host.show(engine.makePlayerViewController())
    }

    private func bindActiveEngine() {
        subscriptions.removeAll()
        active.statePublisher
            .sink { [weak self] state in self?.handle(state) }
            .store(in: &subscriptions)
        active.tracksPublisher
            .sink { [weak self] tracks in self?.tracksSubject.send(tracks) }
            .store(in: &subscriptions)
        active.timePublisher
            .sink { [weak self] time in self?.timeSubject.send(time) }
            .store(in: &subscriptions)
    }

    private func handle(_ state: PlayerState) {
        if case .failed(let failure) = state,
           allowsFallback,
           active === avPlayer,
           !didFallback,
           failure.category == .format || failure.category == .decoding,
           let request {
            didFallback = true
            switchEngine(to: vlc)
            vlc.load(request)
            return
        }
        stateSubject.send(state)
    }
}
