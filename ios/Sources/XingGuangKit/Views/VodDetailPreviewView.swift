import SwiftUI
import UniformTypeIdentifiers

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
    @State private var aspectMode: PlayerAspectMode
    @State private var zoomScale: CGFloat = 1
    @State private var reverseSort = false
    @State private var opening = 0.0
    @State private var ending = 0.0
    @State private var episodeEndHandled = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var playingEpisodeURL = ""
    @State private var expectedResumePosition = 0.0
    @State private var lastPersistedPosition = 0.0
    @State private var lastPersistedEpisodeURL = ""
    @State private var selectedAudioTrackID = ""
    @State private var selectedVideoTrackID = ""
    @State private var selectedSubtitleTrackID = ""
    @State private var currentPlaybackRequest: PlaybackRequest?
    @State private var subtitleResources: [SubtitleResource] = []
    @State private var danmakuResources: [DanmakuResource] = []
    @State private var subtitleCues: [TimedTextCue] = []
    @State private var danmakuCues: [DanmakuCue] = []
    @State private var selectedSubtitleResourceID = ""
    @State private var selectedDanmakuResourceID = ""
    @State private var overlayTask: Task<Void, Never>?
    @State private var isImportingSubtitle = false
    @State private var isImportingDanmaku = false
    @State private var showsOverlaySettings = false

    init(vod: Vod, model: XingGuangAppModel) {
        self.model = model
        _vod = State(initialValue: vod)
        _session = StateObject(wrappedValue: model.makePlayerSession())
        _speed = State(initialValue: model.defaultPlaybackSpeed)
        _aspectMode = State(initialValue: model.defaultAspectMode)
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
            if shouldFinishAtEnding(time) {
                handleEpisodeEnd()
                return
            }
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
        .onReceive(session.$state) { state in
            if case .ended = state, !session.loopEnabled { handleEpisodeEnd() }
        }
        .onReceive(session.$tracks) { tracks in
            selectedAudioTrackID = retainedTrackID(selectedAudioTrackID, in: tracks)
            selectedVideoTrackID = retainedTrackID(selectedVideoTrackID, in: tracks)
            selectedSubtitleTrackID = retainedTrackID(selectedSubtitleTrackID, in: tracks)
        }
        .onDisappear {
            playbackTask?.cancel()
            overlayTask?.cancel()
            persistPlayback()
            session.cancelSleepTimer()
            session.stop()
        }
        .fileImporter(
            isPresented: $isImportingSubtitle,
            allowedContentTypes: [.plainText, .data],
            allowsMultipleSelection: false,
            onCompletion: handleSubtitleSelection
        )
        .fileImporter(
            isPresented: $isImportingDanmaku,
            allowedContentTypes: [.plainText, .xml, .data],
            allowsMultipleSelection: false,
            onCompletion: handleDanmakuSelection
        )
        .sheet(isPresented: $showsOverlaySettings) {
            NavigationView {
                TimedOverlaySettingsView(
                    subtitleTextSize: $model.subtitleTextSize,
                    subtitleBottomOffset: $model.subtitleBottomOffset,
                    danmakuEnabled: $model.danmakuEnabled
                )
            }
        }
        .accessibilityIdentifier("vod.detail")
    }

    private var player: some View {
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
                if model.danmakuEnabled, !danmakuCues.isEmpty {
                    DanmakuOverlayView(cues: danmakuCues, position: session.time.position)
                }
                if !subtitleCues.isEmpty {
                    TimedSubtitleOverlayView(
                        cues: subtitleCues,
                        position: session.time.position,
                        fontSize: model.subtitleTextSize,
                        bottomOffset: model.subtitleBottomOffset
                    )
                }
                playerOverlay
            }
            .clipped()
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
                playbackOptionsMenu
                trackMenu
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
            Section(header: Text("外置字幕")) {
                if !subtitleCues.isEmpty {
                    Button {
                        selectedSubtitleResourceID = ""
                        subtitleCues = []
                    } label: {
                        Label("关闭外置字幕", systemImage: selectedSubtitleResourceID.isEmpty ? "checkmark" : "captions.bubble")
                    }
                }
                ForEach(subtitleResources) { resource in
                    Button { loadSubtitle(resource) } label: {
                        Label(resource.name.isEmpty ? resource.url : resource.name, systemImage: selectedSubtitleResourceID == resource.id ? "checkmark" : "circle")
                    }
                }
                Button { isImportingSubtitle = true } label: {
                    Label("选择字幕文件", systemImage: "doc.badge.plus")
                }
            }
            Section(header: Text("弹幕")) {
                if !danmakuCues.isEmpty {
                    Button { model.danmakuEnabled.toggle() } label: {
                        Label(model.danmakuEnabled ? "关闭弹幕" : "开启弹幕", systemImage: model.danmakuEnabled ? "text.bubble.fill" : "text.bubble")
                    }
                }
                ForEach(danmakuResources) { resource in
                    Button { loadDanmaku(resource) } label: {
                        Label(resource.name.isEmpty ? resource.url : resource.name, systemImage: selectedDanmakuResourceID == resource.id ? "checkmark" : "circle")
                    }
                }
                Button { isImportingDanmaku = true } label: {
                    Label("选择弹幕文件", systemImage: "doc.badge.plus")
                }
            }
            Button { showsOverlaySettings = true } label: {
                Label("字幕与弹幕设置", systemImage: "textformat.size")
            }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .accessibilityLabel("音轨与字幕")
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
                        persistPlayback()
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
            Divider()
            Button {
                opening = max(session.time.position, 0)
                session.loopStart = opening
                persistPlayback()
            } label: {
                Label("片头设为 \(formatTime(session.time.position))", systemImage: "forward.end")
            }
            .disabled(session.time.position <= 0)
            if opening > 0 {
                Button("清除片头", role: .destructive) {
                    opening = 0
                    session.loopStart = 0
                    persistPlayback()
                }
            }
            Button {
                ending = max(session.time.duration - session.time.position, 0)
                persistPlayback()
            } label: {
                Label("片尾设为 \(formatTime(session.time.duration - session.time.position))", systemImage: "backward.end")
            }
            .disabled(session.time.duration <= 0 || session.time.position <= 0)
            if ending > 0 {
                Button("清除片尾", role: .destructive) {
                    ending = 0
                    persistPlayback()
                }
            }
        } label: {
            Image(systemName: session.sleepTimerRemaining > 0 ? "timer" : "ellipsis.circle")
        }
        .accessibilityLabel("播放设置")
    }

    private var sleepTimerTitle: String {
        guard session.sleepTimerRemaining > 0 else { return "定时停止" }
        return "定时停止：\(formatTime(TimeInterval(session.sleepTimerRemaining)))"
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
                HStack(spacing: 8) {
                    SectionTitle(title: "选集")
                    Button {
                        reverseSort.toggle()
                        persistPlayback()
                    } label: {
                        Label(reverseSort ? "倒序" : "正序", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(XingGuangTheme.primary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54, maximum: 88), spacing: 10)], spacing: 10) {
                    ForEach(displayedEpisodes(in: route), id: \.offset) { index, episode in
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
        reverseSort = history.reverseSort
        opening = Double(max(history.opening, 0)) / 1000
        ending = Double(max(history.ending, 0)) / 1000
        aspectMode = PlayerAspectMode(rawValue: history.scale) ?? model.defaultAspectMode
        session.loopStart = opening
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
                let completed = storedDuration > 0 && storedPosition + max(ending, 5) >= storedDuration
                let resume = completed ? opening : max(storedDuration > 0 ? min(storedPosition, storedDuration) : storedPosition, opening)
                expectedResumePosition = resume
                session.loopStart = opening
                session.load(request, resumeAt: resume)
                session.setRate(Float(speed))
                configureOverlays(for: request)
                playingEpisodeURL = episode.url
                lastPersistedPosition = resume
                lastPersistedEpisodeURL = episode.url
                episodeEndHandled = false
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
        model.savePlayback(
            vod: vod,
            route: route,
            episode: episode,
            time: safeTime,
            speed: speed.isFinite ? speed : 1,
            reverseSort: reverseSort,
            opening: Int64(opening * 1000),
            ending: Int64(ending * 1000),
            scale: aspectMode.rawValue
        )
        lastPersistedPosition = position
        lastPersistedEpisodeURL = episode.url
    }

    private func resetPersistenceCheckpoint() {
        playbackTask?.cancel()
        overlayTask?.cancel()
        session.stop()
        lastPersistedPosition = 0
        lastPersistedEpisodeURL = currentEpisode?.url ?? ""
        playingEpisodeURL = ""
        expectedResumePosition = 0
        episodeEndHandled = false
        currentPlaybackRequest = nil
        subtitleResources = []
        danmakuResources = []
        subtitleCues = []
        danmakuCues = []
        selectedSubtitleResourceID = ""
        selectedDanmakuResourceID = ""
    }

    private func displayedEpisodes(in route: PlaybackRoute) -> [(offset: Int, element: PlaybackEpisode)] {
        let episodes = Array(route.episodes.enumerated())
        return reverseSort ? Array(episodes.reversed()) : episodes
    }

    private func shouldFinishAtEnding(_ time: PlayerTime) -> Bool {
        guard !episodeEndHandled, ending > 0, time.duration > 0, time.position > 0 else { return false }
        return time.position + ending >= time.duration
    }

    private func handleEpisodeEnd() {
        guard !episodeEndHandled else { return }
        episodeEndHandled = true
        persistPlayback()
        if session.loopEnabled {
            session.replay(from: opening)
            episodeEndHandled = false
            return
        }
        let nextIndex = reverseSort ? selectedEpisode - 1 : selectedEpisode + 1
        guard let route = currentRoute, route.episodes.indices.contains(nextIndex) else { return }
        selectedEpisode = nextIndex
        resetPersistenceCheckpoint()
        play(route: route, episode: route.episodes[nextIndex])
    }

    private func configureOverlays(for request: PlaybackRequest) {
        overlayTask?.cancel()
        currentPlaybackRequest = request
        subtitleResources = request.subtitles
        danmakuResources = request.danmaku
        subtitleCues = []
        danmakuCues = []
        selectedSubtitleResourceID = ""
        selectedDanmakuResourceID = ""
        overlayTask = Task { @MainActor in
            if let subtitle = request.subtitles.first {
                await loadSubtitle(subtitle, request: request)
            }
            guard !Task.isCancelled else { return }
            if let danmaku = request.danmaku.first {
                await loadDanmaku(danmaku, request: request)
            }
        }
    }

    private func loadSubtitle(_ resource: SubtitleResource) {
        guard let request = currentPlaybackRequest else { return }
        overlayTask?.cancel()
        overlayTask = Task { @MainActor in
            await loadSubtitle(resource, request: request)
        }
    }

    private func loadSubtitle(_ resource: SubtitleResource, request: PlaybackRequest) async {
        do {
            let cues = try await model.loadSubtitle(resource, request: request)
            try Task.checkCancellation()
            subtitleCues = cues
            selectedSubtitleResourceID = resource.id
        } catch is CancellationError {
        } catch {
            detailError = error.localizedDescription
        }
    }

    private func loadDanmaku(_ resource: DanmakuResource) {
        guard let request = currentPlaybackRequest else { return }
        overlayTask?.cancel()
        overlayTask = Task { @MainActor in
            await loadDanmaku(resource, request: request)
        }
    }

    private func loadDanmaku(_ resource: DanmakuResource, request: PlaybackRequest) async {
        do {
            let cues = try await model.loadDanmaku(resource, request: request)
            try Task.checkCancellation()
            danmakuCues = cues
            selectedDanmakuResourceID = resource.id
        } catch is CancellationError {
        } catch {
            detailError = error.localizedDescription
        }
    }

    private func handleSubtitleSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { detailError = error.localizedDescription }
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let cues = try TimedTextParser.subtitles(data: Data(contentsOf: url), url: url.absoluteString)
            let resource = SubtitleResource(url: url.absoluteString, name: url.lastPathComponent, format: url.pathExtension)
            subtitleResources.removeAll { $0.id == resource.id }
            subtitleResources.insert(resource, at: 0)
            subtitleCues = cues
            selectedSubtitleResourceID = resource.id
        } catch {
            detailError = error.localizedDescription
        }
    }

    private func handleDanmakuSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { detailError = error.localizedDescription }
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let cues = try TimedTextParser.danmaku(data: Data(contentsOf: url), url: url.absoluteString)
            let resource = DanmakuResource(url: url.absoluteString, name: url.lastPathComponent, format: url.pathExtension)
            danmakuResources.removeAll { $0.id == resource.id }
            danmakuResources.insert(resource, at: 0)
            danmakuCues = cues
            selectedDanmakuResourceID = resource.id
            model.danmakuEnabled = true
        } catch {
            detailError = error.localizedDescription
        }
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

private struct TimedOverlaySettingsView: View {
    @Binding var subtitleTextSize: Double
    @Binding var subtitleBottomOffset: Double
    @Binding var danmakuEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("字幕") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("字号 \(Int(subtitleTextSize))")
                    Slider(value: $subtitleTextSize, in: 14...42, step: 1)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("底部位置 \(Int(subtitleBottomOffset))")
                    Slider(value: $subtitleBottomOffset, in: 8...120, step: 4)
                }
                Button("恢复默认") {
                    subtitleTextSize = 22
                    subtitleBottomOffset = 24
                }
            }
            Section("弹幕") {
                Toggle("显示弹幕", isOn: $danmakuEnabled)
            }
        }
        .navigationTitle("字幕与弹幕")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }
}
