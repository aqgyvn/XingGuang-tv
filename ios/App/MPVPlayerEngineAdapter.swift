import Combine
import Foundation
import QuartzCore
import UIKit
import XingGuangKit

#if canImport(Libmpv)
import Libmpv

final class MPVPlayerEngineAdapter: PlayerEngine {
    let kind: PlayerEngineKind = .mpv
    let capabilities: Set<PlayerCapability> = [.backgroundAudio, .externalSubtitles, .trackSelection]
    var state: PlayerState { stateSubject.value }
    var tracks: [PlayerTrack] { tracksSubject.value }
    var time: PlayerTime { timeSubject.value }
    var statePublisher: AnyPublisher<PlayerState, Never> { stateSubject.eraseToAnyPublisher() }
    var tracksPublisher: AnyPublisher<[PlayerTrack], Never> { tracksSubject.eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<PlayerTime, Never> { timeSubject.eraseToAnyPublisher() }

    private let controller = MPVPlayerViewController()
    private let eventQueue = DispatchQueue(label: "com.xingguang.player.mpv", qos: .userInitiated)
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)
    private let tracksSubject = CurrentValueSubject<[PlayerTrack], Never>([])
    private let timeSubject = CurrentValueSubject<PlayerTime, Never>(PlayerTime())
    private var context: OpaquePointer?

    init() {
        eventQueue.sync { setup() }
    }

    func load(_ request: PlaybackRequest) {
        guard URL(string: request.url) != nil else {
            publish(.failed(PlayerFailure(category: .format, message: "Invalid playback URL")))
            return
        }
        if let drm = request.drm, !drm.type.isEmpty {
            publish(.failed(PlayerFailure(category: .drm, message: "MPV does not support DRM: \(drm.type)")))
            return
        }
        publish(.loading)
        eventQueue.async { [weak self] in
            guard let self, let context = self.context else { return }
            self.applyNetworkOptions(request, context: context)
            self.command("loadfile", arguments: [request.url, "replace"])
            for subtitle in request.subtitles where !subtitle.url.isEmpty {
                self.command("sub-add", arguments: [subtitle.url, "auto", subtitle.name])
            }
        }
    }

    func play() { setProperty("pause", value: "no") }
    func pause() { setProperty("pause", value: "yes") }
    func seek(to position: TimeInterval) {
        command("seek", arguments: [String(max(position, 0)), "absolute", "exact"])
    }
    func setRate(_ rate: Float) {
        setProperty("speed", value: String(max(rate, 0.1)))
    }
    func select(track: PlayerTrack?) {
        guard let track else {
            setProperty("sid", value: "no")
            return
        }
        let parts = track.id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch track.kind {
        case .audio: setProperty("aid", value: parts[1])
        case .subtitle: setProperty("sid", value: parts[1])
        case .video: setProperty("vid", value: parts[1])
        }
    }
    func stop() {
        command("stop")
        publish(.idle)
        publishTime(PlayerTime())
    }
    func makePlayerViewController() -> UIViewController { controller }
    func startPictureInPicture() -> Bool { false }

    func dispose() {
        eventQueue.sync {
            guard let context else { return }
            mpv_set_wakeup_callback(context, nil, nil)
            mpv_terminate_destroy(context)
            self.context = nil
        }
    }

    private func setup() {
        guard let context = mpv_create() else {
            publish(.failed(PlayerFailure(category: .unknown, message: "Unable to create MPV context")))
            return
        }
        self.context = context
        var windowID = Int64(Int(bitPattern: Unmanaged.passUnretained(controller.metalLayer).toOpaque()))
        mpv_set_option(context, "wid", MPV_FORMAT_INT64, &windowID)
        mpv_set_option_string(context, "vo", "gpu-next")
        mpv_set_option_string(context, "gpu-api", "vulkan")
        mpv_set_option_string(context, "gpu-context", "moltenvk")
        mpv_set_option_string(context, "hwdec", "videotoolbox")
        mpv_set_option_string(context, "ytdl", "no")
        guard mpv_initialize(context) >= 0 else {
            mpv_terminate_destroy(context)
            self.context = nil
            publish(.failed(PlayerFailure(category: .unknown, message: "Unable to initialize MPV")))
            return
        }
        mpv_observe_property(context, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(context, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(context, 0, "demuxer-cache-time", MPV_FORMAT_DOUBLE)
        mpv_observe_property(context, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(context, 0, "paused-for-cache", MPV_FORMAT_FLAG)
        mpv_observe_property(context, 0, "track-list/count", MPV_FORMAT_INT64)
        mpv_set_wakeup_callback(context, { rawContext in
            guard let rawContext else { return }
            Unmanaged<MPVPlayerEngineAdapter>.fromOpaque(rawContext).takeUnretainedValue().scheduleEventRead()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func scheduleEventRead() {
        eventQueue.async { [weak self] in self?.readEvents() }
    }

    private func readEvents() {
        guard let context else { return }
        while let event = mpv_wait_event(context, 0), event.pointee.event_id != MPV_EVENT_NONE {
            switch event.pointee.event_id {
            case MPV_EVENT_START_FILE:
                publish(.loading)
            case MPV_EVENT_FILE_LOADED:
                refreshTracks()
                let duration = getDouble("duration")
                publish(.ready(duration: duration))
                publish(.playing)
                refreshTime()
            case MPV_EVENT_END_FILE:
                if event.pointee.error < 0 {
                    publish(.failed(PlayerFailure(category: .decoding, message: errorMessage(event.pointee.error))))
                } else {
                    publish(.ended)
                }
            case MPV_EVENT_PROPERTY_CHANGE:
                handlePropertyChange(event.pointee.data)
            default:
                break
            }
        }
    }

    private func handlePropertyChange(_ data: UnsafeMutableRawPointer?) {
        guard let data else { return }
        let property = data.assumingMemoryBound(to: mpv_event_property.self).pointee
        let name = String(cString: property.name)
        switch name {
        case "pause":
            guard let value = property.data?.assumingMemoryBound(to: Int32.self).pointee else { return }
            publish(value == 0 ? .playing : .paused)
        case "paused-for-cache":
            guard let value = property.data?.assumingMemoryBound(to: Int32.self).pointee else { return }
            if value != 0 { publish(.loading) }
        case "track-list/count":
            refreshTracks()
        case "time-pos", "duration", "demuxer-cache-time":
            refreshTime()
        default:
            break
        }
    }

    private func refreshTime() {
        let position = getDouble("time-pos")
        let duration = getDouble("duration")
        let cache = getDouble("demuxer-cache-time")
        publishTime(PlayerTime(position: position, duration: duration, buffered: max(position + cache, position)))
    }

    private func refreshTracks() {
        let count = max(Int(getInt64("track-list/count")), 0)
        var result: [PlayerTrack] = []
        for index in 0..<count {
            guard let type = getString("track-list/\(index)/type"),
                  let id = getString("track-list/\(index)/id") else { continue }
            let kind: PlayerTrack.Kind
            switch type {
            case "audio": kind = .audio
            case "sub": kind = .subtitle
            case "video": kind = .video
            default: continue
            }
            let title = getString("track-list/\(index)/title") ?? type.uppercased()
            let language = getString("track-list/\(index)/lang") ?? ""
            result.append(PlayerTrack(id: "\(type):\(id)", kind: kind, name: title, language: language))
        }
        DispatchQueue.main.async { [weak self] in self?.tracksSubject.send(result) }
    }

    private func applyNetworkOptions(_ request: PlaybackRequest, context: OpaquePointer) {
        var headers = request.headers
        if !request.cookies.isEmpty {
            headers["Cookie"] = request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        }
        let headerValue = headers.map { "\($0.key): \($0.value)" }.joined(separator: ",")
        mpv_set_option_string(context, "http-header-fields", headerValue)
    }

    private func command(_ name: String, arguments: [String] = []) {
        eventQueue.async { [weak self] in self?.runCommand(name, arguments: arguments) }
    }

    private func runCommand(_ name: String, arguments: [String]) {
        guard let context else { return }
        var values = ([name] + arguments).map { UnsafePointer<CChar>(strdup($0)) }
        values.append(nil)
        defer {
            for value in values where value != nil {
                free(UnsafeMutablePointer(mutating: value))
            }
        }
        mpv_command(context, &values)
    }

    private func setProperty(_ name: String, value: String) {
        eventQueue.async { [weak self] in
            guard let context = self?.context else { return }
            mpv_set_property_string(context, name, value)
        }
    }

    private func getDouble(_ name: String) -> Double {
        guard let context else { return 0 }
        var value = 0.0
        return mpv_get_property(context, name, MPV_FORMAT_DOUBLE, &value) >= 0 ? value : 0
    }

    private func getInt64(_ name: String) -> Int64 {
        guard let context else { return 0 }
        var value: Int64 = 0
        return mpv_get_property(context, name, MPV_FORMAT_INT64, &value) >= 0 ? value : 0
    }

    private func getString(_ name: String) -> String? {
        guard let context, let value = mpv_get_property_string(context, name) else { return nil }
        defer { mpv_free(value) }
        return String(cString: value)
    }

    private func errorMessage(_ code: Int32) -> String {
        guard let value = mpv_error_string(code) else { return "MPV playback failed" }
        return "MPV playback failed: \(String(cString: value))"
    }

    private func publish(_ state: PlayerState) {
        DispatchQueue.main.async { [weak self] in self?.stateSubject.send(state) }
    }

    private func publishTime(_ time: PlayerTime) {
        DispatchQueue.main.async { [weak self] in self?.timeSubject.send(time) }
    }
}

private final class MPVPlayerViewController: UIViewController {
    let metalLayer = StableMetalLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(metalLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metalLayer.frame = view.bounds
    }
}

private final class StableMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            if newValue.width > 1, newValue.height > 1 { super.drawableSize = newValue }
        }
    }
}

#else

final class MPVPlayerEngineAdapter: UnavailablePlayerEngine {
    init() { super.init(kind: .mpv, message: "MPVKit is not linked") }
}

#endif
