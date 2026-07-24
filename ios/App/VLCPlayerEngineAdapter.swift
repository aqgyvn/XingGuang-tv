import Combine
import Foundation
import UIKit
import XingGuangKit

#if canImport(MobileVLCKit)
import MobileVLCKit

final class VLCPlayerEngineAdapter: NSObject, PlayerEngine, VLCMediaPlayerDelegate {
    let kind: PlayerEngineKind = .vlc
    let capabilities: Set<PlayerCapability> = [.backgroundAudio]
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { timeSubject.value }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    private let mediaPlayer = VLCMediaPlayer()
    private let controller = VLCPlayerViewController()
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())

    override init() {
        super.init()
        mediaPlayer.delegate = self
        mediaPlayer.drawable = controller.view
    }

    func load(_ request: PlaybackRequest) {
        guard let url = URL(string: request.url) else {
            fail("播放地址无效")
            return
        }
        if let drm = request.drm, !drm.type.isEmpty {
            stateSubject.send(.failed(PlayerFailure(category: .drm, message: "VLC 不支持此 DRM：\(drm.type)")))
            return
        }
        let media = VLCMedia(url: url)
        var options: [String: Any] = ["network-caching": max(Int(request.timeout * 1000), 1000)]
        for (key, value) in request.headers {
            switch key.lowercased() {
            case "user-agent": options["http-user-agent"] = value
            case "referer", "referrer": options["http-referrer"] = value
            case "cookie": options["http-cookie"] = value
            default: break
            }
        }
        if !request.cookies.isEmpty {
            options["http-cookie"] = request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        }
        media.addOptions(options)
        stateSubject.send(.loading)
        mediaPlayer.media = media
        mediaPlayer.play()
    }

    func play() { mediaPlayer.play() }
    func pause() { mediaPlayer.pause() }
    func seek(to position: TimeInterval) { mediaPlayer.time = VLCTime(int: Int32(max(position, 0) * 1000)) }
    func setRate(_ rate: Float) { mediaPlayer.rate = rate }
    func select(track: PlayerTrack?) {}
    func stop() {
        mediaPlayer.stop()
        stateSubject.send(.idle)
        timeSubject.send(PlayerTime())
    }
    func makePlayerViewController() -> UIViewController { controller }
    func startPictureInPicture() -> Bool { false }
    func release() {
        mediaPlayer.stop()
        mediaPlayer.delegate = nil
        mediaPlayer.drawable = nil
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        switch mediaPlayer.state {
        case .opening, .buffering:
            stateSubject.send(.loading)
        case .playing:
            stateSubject.send(.playing)
        case .paused:
            stateSubject.send(.paused)
        case .ended:
            stateSubject.send(.ended)
        case .error:
            fail("VLC 无法播放此媒体")
        case .stopped:
            stateSubject.send(.idle)
        default:
            break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        let position = Double(mediaPlayer.time.intValue) / 1000
        let duration = Double(mediaPlayer.media?.length.intValue ?? 0) / 1000
        timeSubject.send(PlayerTime(position: position, duration: duration, buffered: position))
    }

    private func fail(_ message: String) {
        stateSubject.send(.failed(PlayerFailure(category: .format, message: message)))
    }
}

#else

final class VLCPlayerEngineAdapter: PlayerEngine {
    let kind: PlayerEngineKind = .vlc
    let capabilities: Set<PlayerCapability> = []
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { [] }
    var time: PlayerTime { PlayerTime() }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { Just([]).eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { Just(PlayerTime()).eraseToAnyPublisher() }

    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)

    func load(_ request: PlaybackRequest) {
        stateSubject.send(.failed(PlayerFailure(category: .format, message: "MobileVLCKit 未集成")))
    }
    func play() {}
    func pause() {}
    func seek(to position: TimeInterval) {}
    func setRate(_ rate: Float) {}
    func select(track: PlayerTrack?) {}
    func stop() { stateSubject.send(.idle) }
    func makePlayerViewController() -> UIViewController { VLCPlayerViewController() }
    func startPictureInPicture() -> Bool { false }
    func release() {}
}

#endif

private final class VLCPlayerViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}
