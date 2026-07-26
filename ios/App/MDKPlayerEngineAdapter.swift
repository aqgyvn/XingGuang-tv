import Combine
import Foundation
import UIKit
import XingGuangKit

#if canImport(swift_mdk)
import swift_mdk

final class MDKPlayerEngineAdapter: PlayerEngine {
    let kind: PlayerEngineKind = .mdk
    let capabilities: Set<PlayerCapability> = [.backgroundAudio, .externalSubtitles, .trackSelection]
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { tracksSubject.value }
    var time: PlayerTime { timeSubject.value }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { tracksSubject.eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    private let player: Player
    private let controller: MDKPlayerViewController
    private let engineQueue = DispatchQueue(label: "com.xingguang.player.mdk", qos: .userInitiated)
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let tracksSubject = CurrentValueSubject<[PlayerTrack], Never>([])
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())
    private var timer: DispatchSourceTimer?

    init() {
        if let key = Bundle.main.object(forInfoDictionaryKey: "MDKLicenseKey") as? String, !key.isEmpty {
            setGlobalOption(name: "MDK_KEY", value: key)
        }
        player = Player()
        controller = MDKPlayerViewController()
        player.videoDecoders = ["VT:copy=0", "VideoToolbox", "FFmpeg"]
        controller.onViewReady = { [weak self] surface in
            self?.engineQueue.async { [weak self] in
                self?.player.updateNativeSurface(surface, width: 0, height: 0)
            }
        }
        player.onStateChanged { [weak self] state in
            self?.handle(state: state)
        }
        player.onMediaStatusChanged { [weak self] status in
            self?.engineQueue.async { [weak self] in self?.handle(status: status.rawValue) }
            return true
        }
        startTimer()
    }

    func load(_ request: PlaybackRequest) {
        guard URL(string: request.url) != nil else {
            publish(.failed(PlayerFailure(category: .format, message: "Invalid playback URL")))
            return
        }
        if let drm = request.drm, !drm.type.isEmpty {
            publish(.failed(PlayerFailure(category: .drm, message: "MDK does not support DRM: \(drm.type)")))
            return
        }
        publish(.loading)
        engineQueue.async { [weak self] in
            guard let self else { return }
            self.applyNetworkOptions(request)
            if let subtitle = request.subtitles.first, !subtitle.url.isEmpty {
                self.player.set(media: subtitle.url, forType: .Subtitle)
            }
            self.player.media = request.url
            self.player.state = .Playing
        }
    }

    func play() { engineQueue.async { [weak self] in self?.player.state = .Playing } }
    func pause() { engineQueue.async { [weak self] in self?.player.state = .Paused } }
    func seek(to position: TimeInterval) {
        engineQueue.async { [weak self] in
            self?.player.seek(Int64(max(position, 0) * 1000), callback: nil)
        }
    }
    func setRate(_ rate: Float) {
        engineQueue.async { [weak self] in self?.player.playbackRate = max(rate, 0.1) }
    }
    func select(track: PlayerTrack?) {
        guard let track, let index = Int(track.id.split(separator: ":").last ?? "") else { return }
        engineQueue.async { [weak self] in
            switch track.kind {
            case .audio: self?.player.activeAudioTracks = [index]
            case .subtitle: self?.player.activeSubtitleTracks = [index]
            case .video: self?.player.activeVideoTracks = [index]
            }
        }
    }
    func stop() {
        engineQueue.async { [weak self] in self?.player.state = .Stopped }
        publish(.idle)
        publishTime(PlayerTime())
    }
    func makePlayerViewController() -> UIViewController { controller }
    func startPictureInPicture() -> Bool { false }

    func dispose() {
        timer?.cancel()
        timer = nil
        player.onStateChanged(callback: nil)
        player.onMediaStatusChanged(callback: nil)
        player.state = .Stopped
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: engineQueue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in self?.refreshTime() }
        timer.resume()
        self.timer = timer
    }

    private func handle(state: State) {
        switch state {
        case .Playing: publish(.playing)
        case .Paused: publish(.paused)
        case .Stopped: break
        }
    }

    private func handle(status: Int32) {
        let invalid = Int32(bitPattern: UInt32(1) << 31)
        if status & invalid != 0 {
            publish(.failed(PlayerFailure(category: .decoding, message: "MDK playback failed")))
        } else if status & (1 << 6) != 0 {
            publish(.ended)
        } else if status & ((1 << 2) | (1 << 8)) != 0 {
            refreshTracks()
            publish(.ready(duration: Double(player.mediaInfo.duration) / 1000))
        } else if status & ((1 << 1) | (1 << 3) | (1 << 4) | (1 << 7)) != 0 {
            publish(.loading)
        }
    }

    private func refreshTime() {
        let position = Double(player.position) / 1000
        let duration = Double(player.mediaInfo.duration) / 1000
        let buffered = Double(player.buffered()) / 1000
        publishTime(PlayerTime(position: position, duration: duration, buffered: max(buffered, position)))
    }

    private func refreshTracks() {
        let info = player.mediaInfo
        var result = info.audio.map {
            PlayerTrack(
                id: "audio:\($0.index)",
                kind: .audio,
                name: $0.metadata["title"] ?? "Audio \($0.index)",
                language: $0.metadata["language"] ?? ""
            )
        }
        result += info.subtitle.map {
            PlayerTrack(
                id: "subtitle:\($0.index)",
                kind: .subtitle,
                name: $0.metadata["title"] ?? "Subtitle \($0.index)",
                language: $0.metadata["language"] ?? ""
            )
        }
        result += info.video.map {
            PlayerTrack(id: "video:\($0.index)", kind: .video, name: "Video \($0.index)")
        }
        DispatchQueue.main.async { [weak self] in self?.tracksSubject.send(result) }
    }

    private func applyNetworkOptions(_ request: PlaybackRequest) {
        let userAgent = request.headers.first { $0.key.lowercased() == "user-agent" }?.value ?? ""
        let referer = request.headers.first { ["referer", "referrer"].contains($0.key.lowercased()) }?.value ?? ""
        let extraHeaders = request.headers
            .filter { !["user-agent", "referer", "referrer", "cookie"].contains($0.key.lowercased()) }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\r\n")
        let headerCookies = request.headers.first { $0.key.lowercased() == "cookie" }?.value ?? ""
        let cookies = request.cookies.isEmpty
            ? headerCookies
            : request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        player.setProperty(name: "avio.user_agent", value: userAgent)
        player.setProperty(name: "avio.referer", value: referer)
        player.setProperty(name: "avio.headers", value: extraHeaders)
        player.setProperty(name: "avio.cookies", value: cookies)
    }

    private func publish(_ state: PlayerState) {
        DispatchQueue.main.async { [weak self] in self?.stateSubject.send(state) }
    }

    private func publishTime(_ time: PlayerTime) {
        DispatchQueue.main.async { [weak self] in self?.timeSubject.send(time) }
    }
}

private final class MDKPlayerViewController: UIViewController {
    var onViewReady: ((UIView) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        onViewReady?(view)
    }
}

#else

final class MDKPlayerEngineAdapter: UnavailablePlayerEngine {
    init() { super.init(kind: .mdk, message: "swift-mdk is not linked") }
}

#endif
