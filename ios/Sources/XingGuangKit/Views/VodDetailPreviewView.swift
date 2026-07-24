import SwiftUI

@MainActor
struct VodDetailPreviewView: View {
    @ObservedObject var model: XingGuangAppModel
    @StateObject private var session: PlayerSession
    @State private var vod: Vod
    @State private var selectedRoute = 0
    @State private var selectedEpisode = 0
    @State private var detailLoading = false
    @State private var detailError = ""
    @State private var seekPosition = 0.0
    @State private var seeking = false
    @State private var speed = 1.0

    init(vod: Vod, model: XingGuangAppModel) {
        self.model = model
        _vod = State(initialValue: vod)
        _session = StateObject(wrappedValue: model.makePlayerSession())
    }

    private var routes: [PlaybackRoute] { vod.playbackRoutes }
    private var currentRoute: PlaybackRoute? { routes.indices.contains(selectedRoute) ? routes[selectedRoute] : routes.first }
    private var currentEpisode: PlaybackEpisode? {
        guard let route = currentRoute else { return nil }
        return route.episodes.indices.contains(selectedEpisode) ? route.episodes[selectedEpisode] : route.episodes.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                player
                summary
                if detailLoading { ProgressView("正在加载详情").padding(.horizontal, 16) }
                if !detailError.isEmpty { Text(detailError).foregroundColor(.red).padding(.horizontal, 16) }
                routePicker
                episodesGrid
                description
            }
            .padding(.bottom, 24)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle(vod.vodName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    _ = model.toggleKeep(vod: vod)
                } label: {
                    Image(systemName: model.isKept(vod) ? "star.fill" : "star")
                }
                .accessibilityLabel(model.isKept(vod) ? "取消收藏" : "收藏")
            }
        }
        .task { await loadDetail() }
        .onReceive(session.$time) { time in
            if !seeking { seekPosition = time.position }
        }
        .onDisappear {
            persistPlayback()
            session.stop()
        }
        .accessibilityIdentifier("vod.detail")
    }

    private var player: some View {
        VStack(spacing: 0) {
            ZStack {
                PlayerSurfaceView(engine: session.engine)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                playerOverlay
            }
            controls
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var playerOverlay: some View {
        switch session.state {
        case .idle:
            playButton
        case .loading:
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
        case .ready, .paused, .ended:
            playButton
        case .playing:
            EmptyView()
        case .failed(let failure):
            VStack(spacing: 10) {
                Image(systemName: failure.category == .drm ? "lock.trianglebadge.exclamationmark" : "exclamationmark.triangle")
                Text(failure.message).multilineTextAlignment(.center)
                playButton
            }
            .foregroundColor(.white)
            .padding(16)
        }
    }

    private var playButton: some View {
        Button {
            if case .paused = session.state {
                session.togglePlayback()
            } else if case .ready = session.state {
                session.togglePlayback()
            } else {
                playSelectedEpisode()
            }
        } label: {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 58))
                .foregroundColor(XingGuangTheme.primary)
        }
        .accessibilityLabel("播放")
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Slider(
                value: $seekPosition,
                in: 0...max(session.time.duration, 1),
                onEditingChanged: { editing in
                    seeking = editing
                    if !editing { session.engine.seek(to: seekPosition) }
                }
            )
            HStack {
                Button { session.togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                Text("\(formatTime(seekPosition)) / \(formatTime(session.time.duration))")
                    .font(.caption.monospacedDigit())
                Spacer()
                Text(session.engine.kind == .avPlayer ? "AVPlayer" : "VLC")
                    .font(.caption)
                if session.engine.capabilities.contains(.pictureInPicture) {
                    Button {
                        _ = session.engine.startPictureInPicture()
                    } label: {
                        Image(systemName: "pip")
                    }
                    .accessibilityLabel("画中画")
                }
                Menu {
                    ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                        Button("\(value, specifier: "%g")x") {
                            speed = value
                            session.engine.setRate(Float(value))
                        }
                    }
                } label: {
                    Text("\(speed, specifier: "%g")x")
                }
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var isPlaying: Bool {
        if case .playing = session.state { return true }
        return false
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vod.vodName)
                .font(.title2.weight(.semibold))
                .foregroundColor(XingGuangTheme.text)
            HStack(spacing: 8) {
                if !vod.vodRemarks.isEmpty { badge(vod.vodRemarks) }
                if !vod.vodYear.isEmpty { badge(vod.vodYear) }
                if !vod.typeName.isEmpty { badge(vod.typeName) }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var routePicker: some View {
        if !routes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "线路")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            Button {
                                persistPlayback()
                                selectedRoute = index
                                selectedEpisode = 0
                            } label: {
                                routeLabel(route.name, selected: index == selectedRoute)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var episodesGrid: some View {
        if let route = currentRoute {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "选集", trailing: "正序")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54, maximum: 88), spacing: 10)], spacing: 10) {
                    ForEach(Array(route.episodes.enumerated()), id: \.element.id) { index, episode in
                        Button {
                            persistPlayback()
                            selectedEpisode = index
                            play(route: route, episode: episode)
                        } label: {
                            Text(episode.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                                .foregroundColor(selectedEpisode == index ? .white : XingGuangTheme.text)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(selectedEpisode == index ? XingGuangTheme.primary : XingGuangTheme.panel)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(XingGuangTheme.border, lineWidth: selectedEpisode == index ? 0 : 1))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "简介")
            Text(vod.vodContent.isEmpty ? "暂无简介" : vod.vodContent)
                .font(.body)
                .foregroundColor(XingGuangTheme.text)
                .lineSpacing(5)
        }
        .padding(16)
        .xingGuangPanel()
        .padding(.horizontal, 16)
    }

    private func loadDetail() async {
        detailLoading = true
        detailError = ""
        do {
            vod = try await model.detail(for: vod)
            restoreSelection()
        } catch {
            detailError = error.localizedDescription
        }
        detailLoading = false
    }

    private func restoreSelection() {
        guard let history = model.history(for: vod) else { return }
        if let routeIndex = routes.firstIndex(where: { $0.name == history.vodFlag }) {
            selectedRoute = routeIndex
            if let episodeIndex = routes[routeIndex].episodes.firstIndex(where: { $0.url == history.episodeURL }) {
                selectedEpisode = episodeIndex
            }
        }
        speed = history.speed
    }

    private func playSelectedEpisode() {
        guard let route = currentRoute, let episode = currentEpisode else { return }
        play(route: route, episode: episode)
    }

    private func play(route: PlaybackRoute, episode: PlaybackEpisode) {
        Task {
            do {
                let request = try await model.resolvePlayback(route: route, episode: episode)
                let history = model.history(for: vod)
                let resume = history?.episodeURL == episode.url ? Double(max(history?.position ?? 0, 0)) / 1000 : 0
                session.load(request, resumeAt: resume)
                session.engine.setRate(Float(speed))
            } catch {
                detailError = error.localizedDescription
            }
        }
    }

    private func persistPlayback() {
        guard let route = currentRoute, let episode = currentEpisode, session.time.position > 0 else { return }
        model.savePlayback(vod: vod, route: route, episode: episode, time: session.time, speed: speed)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundColor(XingGuangTheme.text)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(XingGuangTheme.panelAccent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func routeLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.body.weight(.medium))
            .foregroundColor(selected ? XingGuangTheme.primary : XingGuangTheme.text)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(XingGuangTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? XingGuangTheme.primary : XingGuangTheme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let total = max(Int(value), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
