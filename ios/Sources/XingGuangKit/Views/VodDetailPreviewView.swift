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
    @State private var playbackTask: Task<Void, Never>?
    @State private var playingEpisodeURL = ""
    @State private var expectedResumePosition = 0.0
    @State private var lastPersistedPosition = 0.0
    @State private var lastPersistedEpisodeURL = ""
    @State private var selectedAudioTrackID = ""
    @State private var selectedVideoTrackID = ""
    @State private var selectedSubtitleTrackID = ""

    init(vod: Vod, model: XingGuangAppModel) {
        self.model = model
        _vod = State(initialValue: vod)
        _session = StateObject(wrappedValue: model.makePlayerSession())
        _speed = State(initialValue: model.defaultPlaybackSpeed)
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
            if !seeking, time.position.isFinite { seekPosition = max(time.position, 0) }
            guard let episode = currentEpisode else { return }
            guard playingEpisodeURL == episode.url else { return }
            if expectedResumePosition > 0 {
                if time.position >= max(expectedResumePosition - 5, 0) {
                    expectedResumePosition = 0
                    lastPersistedPosition = time.position
                }
                return
            }
            if lastPersistedEpisodeURL != episode.url {
                lastPersistedEpisodeURL = episode.url
                lastPersistedPosition = 0
            }
            if time.position.isFinite, abs(time.position - lastPersistedPosition) >= 15 {
                persistPlayback()
            }
        }
        .onReceive(session.$tracks) { tracks in
            selectedAudioTrackID = retainedTrackID(selectedAudioTrackID, in: tracks)
            selectedVideoTrackID = retainedTrackID(selectedVideoTrackID, in: tracks)
            selectedSubtitleTrackID = retainedTrackID(selectedSubtitleTrackID, in: tracks)
        }
        .onDisappear {
            playbackTask?.cancel()
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
                in: 0...playbackDuration,
                onEditingChanged: { editing in
                    seeking = editing
                    if !editing { session.seek(to: seekPosition) }
                }
            )
            HStack {
                Button { session.togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                Text("\(formatTime(seekPosition)) / \(formatTime(session.time.duration))")
                    .font(.caption.monospacedDigit())
                Spacer()
                if session.capabilities.contains(.trackSelection), !session.tracks.isEmpty {
                    trackMenu
                }
                if session.capabilities.contains(.pictureInPicture), canRequestPictureInPicture {
                    Button {
                        if !session.startPictureInPicture() {
                            detailError = "画中画暂不可用，请先开始播放"
                        }
                    } label: {
                        Image(systemName: "pip")
                    }
                    .accessibilityLabel("画中画")
                }
                Menu {
                    ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                        Button("\(value, specifier: "%g")x") {
                            speed = value
                            session.setRate(Float(value))
                            persistPlayback()
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

    private var canRequestPictureInPicture: Bool {
        switch session.state {
        case .loading, .ready, .playing, .paused: return true
        case .idle, .ended, .failed: return false
        }
    }

    private var playbackDuration: TimeInterval {
        session.time.duration.isFinite ? max(session.time.duration, 1) : 1
    }

    private var audioTracks: [PlayerTrack] { session.tracks.filter { $0.kind == .audio } }
    private var videoTracks: [PlayerTrack] { session.tracks.filter { $0.kind == .video } }
    private var subtitleTracks: [PlayerTrack] { session.tracks.filter { $0.kind == .subtitle } }

    private var trackMenu: some View {
        Menu {
            if !videoTracks.isEmpty {
                Section(header: Text("视频")) {
                    trackButtons(videoTracks)
                }
            }
            if !audioTracks.isEmpty {
                Section(header: Text("音频")) {
                    trackButtons(audioTracks)
                }
            }
            if !subtitleTracks.isEmpty {
                Section(header: Text("字幕")) {
                    Button {
                        selectedSubtitleTrackID = ""
                        session.select(track: nil)
                    } label: {
                        Label("关闭字幕", systemImage: selectedSubtitleTrackID.isEmpty ? "checkmark" : "captions.bubble")
                    }
                    trackButtons(subtitleTracks)
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .accessibilityLabel("音轨与字幕")
    }

    @ViewBuilder
    private func trackButtons(_ tracks: [PlayerTrack]) -> some View {
        ForEach(tracks) { track in
            Button {
                select(track: track)
            } label: {
                Label(
                    trackDisplayName(track),
                    systemImage: selectedTrackID(for: track.kind) == track.id ? "checkmark" : "circle"
                )
            }
        }
    }

    private func select(track: PlayerTrack) {
        switch track.kind {
        case .audio: selectedAudioTrackID = track.id
        case .video: selectedVideoTrackID = track.id
        case .subtitle: selectedSubtitleTrackID = track.id
        }
        session.select(track: track)
    }

    private func selectedTrackID(for kind: PlayerTrack.Kind) -> String {
        switch kind {
        case .audio: return selectedAudioTrackID
        case .video: return selectedVideoTrackID
        case .subtitle: return selectedSubtitleTrackID
        }
    }

    private func retainedTrackID(_ id: String, in tracks: [PlayerTrack]) -> String {
        tracks.contains(where: { $0.id == id }) ? id : ""
    }

    private func trackDisplayName(_ track: PlayerTrack) -> String {
        guard !track.language.isEmpty, !track.name.localizedCaseInsensitiveContains(track.language) else {
            return track.name
        }
        return "\(track.name) (\(track.language))"
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
                        ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                            Button {
                                guard index != selectedRoute else { return }
                                persistPlayback()
                                selectedRoute = index
                                selectedEpisode = 0
                                resetPersistenceCheckpoint()
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
                    ForEach(Array(route.episodes.enumerated()), id: \.offset) { index, episode in
                        Button {
                            persistPlayback()
                            selectedEpisode = index
                            resetPersistenceCheckpoint()
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
        selectedRoute = 0
        selectedEpisode = 0
        playingEpisodeURL = ""
        expectedResumePosition = 0
        guard let history = model.history(for: vod) else {
            speed = model.defaultPlaybackSpeed
            resetPersistenceCheckpoint()
            return
        }
        if let routeIndex = routes.firstIndex(where: { $0.name == history.vodFlag }) {
            selectedRoute = routeIndex
            if let episodeIndex = routes[routeIndex].episodes.firstIndex(where: { $0.url == history.episodeURL }) {
                selectedEpisode = episodeIndex
            }
        }
        speed = history.speed.isFinite ? min(max(history.speed, 0.5), 2) : model.defaultPlaybackSpeed
        lastPersistedPosition = Double(max(history.position, 0)) / 1000
        lastPersistedEpisodeURL = history.episodeURL
    }

    private func playSelectedEpisode() {
        guard let route = currentRoute, let episode = currentEpisode else { return }
        play(route: route, episode: episode)
    }

    private func play(route: PlaybackRoute, episode: PlaybackEpisode) {
        playbackTask?.cancel()
        detailError = ""
        playbackTask = Task { @MainActor in
            do {
                let request = try await model.resolvePlayback(route: route, episode: episode)
                try Task.checkCancellation()
                let history = model.history(for: vod)
                let storedPosition = history?.episodeURL == episode.url ? Double(max(history?.position ?? 0, 0)) / 1000 : 0
                let storedDuration = history?.episodeURL == episode.url ? Double(max(history?.duration ?? 0, 0)) / 1000 : 0
                let resume = storedDuration > 0 ? min(storedPosition, storedDuration) : storedPosition
                expectedResumePosition = resume
                session.load(request, resumeAt: resume)
                session.setRate(Float(speed))
                playingEpisodeURL = episode.url
                lastPersistedPosition = resume
                lastPersistedEpisodeURL = episode.url
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                detailError = error.localizedDescription
            }
        }
    }

    private func persistPlayback() {
        guard let route = currentRoute, let episode = currentEpisode,
              playingEpisodeURL == episode.url,
              expectedResumePosition == 0,
              session.time.position.isFinite, session.time.position > 0 else { return }
        let position = max(session.time.position, 0)
        let duration = session.time.duration.isFinite ? max(session.time.duration, 0) : 0
        let buffered = session.time.buffered.isFinite ? max(session.time.buffered, 0) : position
        let safeTime = PlayerTime(position: position, duration: duration, buffered: buffered)
        model.savePlayback(vod: vod, route: route, episode: episode, time: safeTime, speed: speed.isFinite ? speed : 1)
        lastPersistedPosition = position
        lastPersistedEpisodeURL = episode.url
    }

    private func resetPersistenceCheckpoint() {
        playbackTask?.cancel()
        session.stop()
        lastPersistedPosition = 0
        lastPersistedEpisodeURL = currentEpisode?.url ?? ""
        playingEpisodeURL = ""
        expectedResumePosition = 0
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
        guard value.isFinite else { return "00:00" }
        let total = max(Int(value), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
