import Foundation
import SwiftUI

@MainActor
struct LocalMediaPlayerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var model: XingGuangAppModel
    @StateObject private var session: PlayerSession
    @State private var seekPosition = 0.0
    @State private var seeking = false
    @State private var speed: Double
    @State private var aspectMode: PlayerAspectMode
    @State private var zoomScale: CGFloat = 1

    private let file: LocalMediaFile
    private let request: PlaybackRequest

    init(file: LocalMediaFile, model: XingGuangAppModel) {
        self.file = file
        self.model = model
        _session = StateObject(wrappedValue: model.makePlayerSession())
        _speed = State(initialValue: model.defaultPlaybackSpeed)
        _aspectMode = State(initialValue: model.defaultAspectMode)
        request = PlaybackRequest(
            url: file.url.absoluteString,
            format: file.url.pathExtension.lowercased(),
            mediaType: "local",
            enginePreference: model.playerPreference
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    PlayerSurfaceView(engine: session.engine)
                        .playerAspect(aspectMode)
                        .scaleEffect(zoomScale)
                    PlayerGestureOverlay(
                        aspectMode: aspectMode,
                        position: session.time.position,
                        duration: session.time.duration,
                        zoomScale: $zoomScale,
                        onSeek: session.seek,
                        onTogglePlayback: session.togglePlayback
                    )
                    playerOverlay
                }
                .clipped()
                .background(Color.black)

                VStack(spacing: 14) {
                    Slider(
                        value: $seekPosition,
                        in: 0...max(session.time.duration, 1),
                        onEditingChanged: { editing in
                            seeking = editing
                            if !editing { session.seek(to: seekPosition) }
                        }
                    )
                    HStack {
                        Text(timeText(session.time.position))
                        Spacer()
                        Text(timeText(session.time.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundColor(XingGuangTheme.secondaryText)

                    HStack(spacing: 18) {
                        Button {
                            session.togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(isPlaying ? "暂停" : "播放")

                        Menu {
                            ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                                Button("\(value, specifier: "%g")x") {
                                    speed = value
                                    session.setRate(Float(value))
                                }
                            }
                        } label: {
                            Text("\(speed, specifier: "%g")x")
                                .frame(minWidth: 44, minHeight: 44)
                        }

                        playbackOptionsMenu

                        Spacer()
                        Text(engineName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(XingGuangTheme.secondaryText)
                    }
                }
                .padding(16)

                Spacer(minLength: 0)
            }
            .background(XingGuangTheme.background.ignoresSafeArea())
            .navigationTitle(file.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            session.setRate(Float(speed))
            session.load(request)
        }
        .onReceive(session.$time) { time in
            if !seeking, time.position.isFinite { seekPosition = max(time.position, 0) }
        }
        .onDisappear {
            session.cancelSleepTimer()
            session.stop()
        }
        .accessibilityIdentifier("localMedia.player")
    }

    private var engineName: String {
        switch session.kind {
        case .mpv: return "MPV"
        case .mdk: return "MDK"
        case .avPlayer: return "AVPlayer"
        }
    }

    private var playbackOptionsMenu: some View {
        Menu {
            Button {
                session.loopEnabled.toggle()
            } label: {
                Label("单集循环", systemImage: session.loopEnabled ? "checkmark" : "repeat.1")
            }
            Menu {
                ForEach([5, 15, 30, 60], id: \.self) { minutes in
                    Button(minutes == 60 ? "1 小时" : "\(minutes) 分钟") {
                        session.setSleepTimer(minutes: minutes)
                    }
                }
                if session.sleepTimerRemaining > 0 {
                    Button("延长 5 分钟") { session.extendSleepTimer() }
                    Button("取消定时器", role: .destructive) { session.cancelSleepTimer() }
                }
            } label: {
                Label(sleepTimerTitle, systemImage: "timer")
            }
            Menu {
                ForEach(PlayerAspectMode.allCases) { mode in
                    Button {
                        aspectMode = mode
                        model.defaultAspectMode = mode
                    } label: {
                        Label(mode.title, systemImage: aspectMode == mode ? "checkmark" : "rectangle")
                    }
                }
            } label: {
                Label("画面比例：\(aspectMode.title)", systemImage: "aspectratio")
            }
            if zoomScale > 1 {
                Button {
                    zoomScale = 1
                } label: {
                    Label("重置缩放", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: session.sleepTimerRemaining > 0 ? "timer" : "ellipsis.circle")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("播放设置")
    }

    private var sleepTimerTitle: String {
        guard session.sleepTimerRemaining > 0 else { return "定时停止" }
        return "定时停止：\(timeText(TimeInterval(session.sleepTimerRemaining)))"
    }

    @ViewBuilder
    private var playerOverlay: some View {
        switch session.state {
        case .idle, .ready, .paused, .ended:
            Button {
                session.togglePlayback()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.white)
            }
            .accessibilityLabel("播放")
        case .loading:
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
        case .playing:
            EmptyView()
        case .failed(let failure):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text(failure.message).multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .padding(16)
        }
    }

    private var isPlaying: Bool {
        if case .playing = session.state { return true }
        return false
    }

    private func timeText(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "00:00" }
        let seconds = Int(value.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
