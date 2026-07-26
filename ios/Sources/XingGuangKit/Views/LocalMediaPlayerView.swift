import Foundation
import SwiftUI

@MainActor
struct LocalMediaPlayerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var session: PlayerSession
    @State private var seekPosition = 0.0
    @State private var seeking = false
    @State private var speed: Double

    private let file: LocalMediaFile
    private let request: PlaybackRequest

    init(file: LocalMediaFile, model: XingGuangAppModel) {
        self.file = file
        _session = StateObject(wrappedValue: model.makePlayerSession())
        _speed = State(initialValue: model.defaultPlaybackSpeed)
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
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    playerOverlay
                }
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

                        Spacer()
                        Text(session.kind == .vlc ? "VLC" : "AVPlayer")
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
        .onDisappear { session.stop() }
        .accessibilityIdentifier("localMedia.player")
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
