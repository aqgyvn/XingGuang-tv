import AVFoundation
import AVKit
import Combine
import Foundation

public final class AVPlayerEngine: NSObject, PlayerEngine {
    public let kind: PlayerEngineKind = .avPlayer
    public let capabilities: Set<PlayerCapability> = [.airPlay, .pictureInPicture, .backgroundAudio, .trackSelection]
    public var state: PlayerState { stateSubject.value }
    public var tracks: [PlayerTrack] { tracksSubject.value }
    public var time: PlayerTime { timeSubject.value }
    public var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    public var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { tracksSubject.eraseToAnyPublisher() }
    public var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    public let player = AVPlayer()
    private let controller = AVPlayerViewController()
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let tracksSubject = CurrentValueSubject<[PlayerTrack], Never>([])
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var selectionOptions: [String: AVMediaSelectionOption] = [:]

    public override init() {
        super.init()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        player.allowsExternalPlayback = true
        configureAudioSession()
        observePlayer()
    }

    public func load(_ request: PlaybackRequest) {
        guard let url = URL(string: request.url) else {
            fail(.unknown, "播放地址无效")
            return
        }
        if let drm = request.drm, !drm.type.isEmpty {
            fail(.drm, "iOS 不支持此 DRM：\(drm.type)")
            return
        }
        stateSubject.send(.loading)
        var headers = request.headers
        if !request.cookies.isEmpty {
            headers["Cookie"] = request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        }
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        observe(item)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    public func play() { player.play() }
    public func pause() { player.pause() }
    public func seek(to position: TimeInterval) { player.seek(to: CMTime(seconds: max(position, 0), preferredTimescale: 600)) }
    public func setRate(_ rate: Float) {
        player.defaultRate = rate
        if player.timeControlStatus == .playing { player.rate = rate }
    }

    public func select(track: PlayerTrack?) {
        guard let item = player.currentItem else { return }
        guard let track else {
            if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                item.select(nil, in: group)
            }
            return
        }
        guard let option = selectionOptions[track.id] else { return }
        let characteristic: AVMediaCharacteristic = track.kind == .subtitle ? .legible : .audible
        if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
            item.select(option, in: group)
        }
    }

    public func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        stateSubject.send(.idle)
        timeSubject.send(PlayerTime())
    }

    public func makePlayerViewController() -> UIViewController { controller }
    public func startPictureInPicture() -> Bool {
        guard controller.isPictureInPicturePossible else { return false }
        controller.startPictureInPicture()
        return true
    }

    public func release() {
        stop()
        playerObservation?.invalidate()
        itemObservation?.invalidate()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            fail(.unknown, "音频会话初始化失败")
        }
    }

    private func observePlayer() {
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            switch player.timeControlStatus {
            case .playing: self.stateSubject.send(.playing)
            case .paused where self.player.currentItem != nil: self.stateSubject.send(.paused)
            case .waitingToPlayAtSpecifiedRate: self.stateSubject.send(.loading)
            @unknown default: break
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            self?.publishTime()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func observe(_ item: AVPlayerItem) {
        itemObservation?.invalidate()
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                let duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                self.stateSubject.send(.ready(duration: duration))
                self.loadTracks(from: item)
            case .failed:
                self.classify(item.error)
            case .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    private func loadTracks(from item: AVPlayerItem) {
        selectionOptions.removeAll()
        var result: [PlayerTrack] = []
        for (kind, characteristic) in [(PlayerTrack.Kind.audio, AVMediaCharacteristic.audible), (.subtitle, .legible)] {
            guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { continue }
            for (index, option) in group.options.enumerated() {
                let id = "\(kind.rawValue):\(index):\(option.displayName)"
                selectionOptions[id] = option
                result.append(PlayerTrack(id: id, kind: kind, name: option.displayName, language: option.extendedLanguageTag ?? option.locale?.identifier ?? ""))
            }
        }
        tracksSubject.send(result)
    }

    private func publishTime() {
        guard let item = player.currentItem else { return }
        let position = player.currentTime().seconds.finiteOrZero
        let duration = item.duration.seconds.finiteOrZero
        let buffered = item.loadedTimeRanges.last.map { $0.timeRangeValue.end.seconds.finiteOrZero } ?? position
        timeSubject.send(PlayerTime(position: position, duration: duration, buffered: buffered))
    }

    private func classify(_ error: Error?) {
        let nsError = error as NSError?
        let underlyingError = nsError?.userInfo[NSUnderlyingErrorKey] as? NSError
        let transportError: NSError?
        if nsError?.domain == NSURLErrorDomain {
            transportError = nsError
        } else if underlyingError?.domain == NSURLErrorDomain {
            transportError = underlyingError
        } else {
            transportError = nil
        }
        if let transportError {
            let code = transportError.code
            let authenticationCodes = [NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication]
            let category: PlayerFailureCategory = authenticationCodes.contains(code) ? .authentication : .network
            fail(category, error?.localizedDescription ?? "网络播放失败")
        } else if nsError?.domain == AVFoundationErrorDomain {
            fail(.format, error?.localizedDescription ?? "AVPlayer 不支持此媒体")
        } else {
            fail(.unknown, error?.localizedDescription ?? "播放失败")
        }
    }

    private func fail(_ category: PlayerFailureCategory, _ message: String) {
        stateSubject.send(.failed(PlayerFailure(category: category, message: message)))
    }

    @objc private func didPlayToEnd() {
        stateSubject.send(.ended)
    }
}

private extension Double {
    var finiteOrZero: Double { isFinite && !isNaN ? self : 0 }
}
