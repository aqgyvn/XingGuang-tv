import SwiftUI

@MainActor
public struct LiveHomeView: View {
    @ObservedObject var model: XingGuangAppModel
    @StateObject private var session: PlayerSession
    @State private var selectedSource = 0
    @State private var selectedGroup = 0
    @State private var selectedChannel = 0
    @State private var selectedLine = 0
    @State private var epg: [Epg] = []
    @State private var selectedEPGDate = ""
    @State private var epgLoading = false
    @State private var epgError = ""
    @State private var playbackError = ""
    @State private var playbackNotice = ""
    @State private var epgTask: Task<Void, Never>?
    @State private var lineFallbackTask: Task<Void, Never>?
    @State private var attemptedLines: Set<Int> = []
    @State private var selectedAudioTrackID = ""
    @State private var selectedVideoTrackID = ""
    @State private var selectedSubtitleTrackID = ""

    public init(model: XingGuangAppModel) {
        self.model = model
        _session = StateObject(wrappedValue: model.makePlayerSession())
    }

    private var source: Live? {
        model.liveSources.indices.contains(selectedSource) ? model.liveSources[selectedSource] : model.liveSources.first
    }

    private var groups: [LiveGroup] {
        guard let source else { return [] }
        let favorites = source.groups
            .flatMap(\.channels)
            .filter { model.isLiveKept(live: source, channel: $0) }
        guard !favorites.isEmpty else { return source.groups }
        return [LiveGroup(name: "收藏", channels: favorites)] + source.groups
    }

    private var channels: [Channel] {
        guard groups.indices.contains(selectedGroup) else { return [] }
        return groups[selectedGroup].channels
    }

    private var currentChannel: Channel? {
        guard channels.indices.contains(selectedChannel) else { return channels.first }
        return channels[selectedChannel]
    }

    private var currentEPG: [EpgData] {
        guard let channel = currentChannel else { return [] }
        let keys = [channel.tvgID, channel.tvgName, channel.name].filter { !$0.isEmpty }
        let candidates = epg.filter { keys.contains($0.key) }
        let channelEPG = candidates.isEmpty ? epg : candidates
        if !selectedEPGDate.isEmpty,
           let dated = channelEPG.first(where: { $0.date == selectedEPGDate }) {
            return dated.list
        }
        return channelEPG.first?.list ?? []
    }

    private var epgDates: [String] {
        Array(Set(epg.map(\.date).filter { !$0.isEmpty })).sorted()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusBanner
                if source != nil {
                    player
                    if !playbackError.isEmpty {
                        Text(playbackError)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    if !playbackNotice.isEmpty {
                        Text(playbackNotice)
                            .font(.subheadline)
                            .foregroundColor(XingGuangTheme.secondaryText)
                    }
                    sourcePicker
                    groupPicker
                    channelGrid
                    epgPanel
                } else {
                    emptyState
                }
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("直播")
        .navigationBarTitleDisplayMode(.inline)
        .task { model.reloadLiveSources() }
        .onChange(of: model.liveSources.map(\.id)) { _ in resetSelection() }
        .onChange(of: selectedSource) { _ in resetSelection(keepSource: true) }
        .onChange(of: selectedGroup) { _ in
            lineFallbackTask?.cancel()
            selectedChannel = 0
            selectedLine = 0
            attemptedLines = []
            selectedEPGDate = ""
            loadEPG()
        }
        .onChange(of: selectedChannel) { _ in
            lineFallbackTask?.cancel()
            selectedLine = 0
            attemptedLines = []
            selectedEPGDate = ""
            loadEPG()
        }
        .onReceive(session.$state) { state in
            handlePlaybackState(state)
        }
        .onReceive(session.$tracks) { tracks in
            selectedAudioTrackID = retainedTrackID(selectedAudioTrackID, in: tracks)
            selectedVideoTrackID = retainedTrackID(selectedVideoTrackID, in: tracks)
            selectedSubtitleTrackID = retainedTrackID(selectedSubtitleTrackID, in: tracks)
        }
        .onDisappear {
            epgTask?.cancel()
            lineFallbackTask?.cancel()
            session.stop()
        }
        .accessibilityIdentifier("live.home")
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch model.liveState {
        case .loading:
            Label("正在加载直播源", systemImage: "arrow.triangle.2.circlepath")
                .foregroundColor(XingGuangTheme.secondaryText)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Button("重新加载") { model.reloadLiveSources() }
                    .buttonStyle(.borderedProminent)
                    .tint(XingGuangTheme.primary)
            }
        default:
            EmptyView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.system(size: 42))
                .foregroundColor(XingGuangTheme.secondaryText)
            Text("暂无可用频道")
                .font(.headline)
                .foregroundColor(XingGuangTheme.text)
            Text("请在设置中填写直播配置，或检查直播源格式。")
                .font(.subheadline)
                .foregroundColor(XingGuangTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("重新加载") { model.reloadLiveSources() }
                .buttonStyle(.borderedProminent)
                .tint(XingGuangTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private var player: some View {
        VStack(spacing: 0) {
            ZStack {
                PlayerSurfaceView(engine: session.engine)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                playerOverlay
            }
            liveControls
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var playerOverlay: some View {
        switch session.state {
        case .idle, .ready, .paused, .ended:
            Button { playCurrent() } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 58))
                    .foregroundColor(XingGuangTheme.primary)
            }
            .accessibilityLabel("播放")
        case .loading:
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
        case .playing:
            EmptyView()
        case .failed(let failure):
            VStack(spacing: 10) {
                Image(systemName: failure.category == .drm ? "lock.trianglebadge.exclamationmark" : "exclamationmark.triangle")
                Text(failure.message).multilineTextAlignment(.center)
                Button { playCurrent() } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 36)) }
            }
            .foregroundColor(.white)
            .padding(16)
        }
    }

    private var liveControls: some View {
        HStack(spacing: 12) {
            Button { session.togglePlayback() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .accessibilityLabel(isPlaying ? "暂停" : "播放")
            Text(currentChannel?.name ?? "")
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let channel = currentChannel, channel.urls.count > 1 {
                Menu {
                    ForEach(Array(channel.urls.indices), id: \.self) { index in
                        Button(lineTitle(channel.urls[index], index: index)) {
                            lineFallbackTask?.cancel()
                            attemptedLines = []
                            selectedLine = index
                            playCurrent(line: index)
                        }
                    }
                } label: {
                    Label("线路", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("切换线路")
            }
            if let source, let channel = currentChannel {
                Button { _ = model.toggleLiveKeep(live: source, channel: channel) } label: {
                    Image(systemName: model.isLiveKept(live: source, channel: channel) ? "star.fill" : "star")
                }
                .accessibilityLabel(model.isLiveKept(live: source, channel: channel) ? "取消收藏频道" : "收藏频道")
            }
            if session.capabilities.contains(.trackSelection), !session.tracks.isEmpty {
                trackMenu
            }
            if session.capabilities.contains(.pictureInPicture), canRequestPictureInPicture {
                Button {
                    if !session.startPictureInPicture() {
                        playbackNotice = "画中画暂不可用，请先开始播放"
                    }
                } label: { Image(systemName: "pip") }
                    .accessibilityLabel("画中画")
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sourcePicker: some View {
        Group {
            if model.liveSources.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(model.liveSources.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selectedSource = index
                            } label: {
                                Text(item.name)
                                    .foregroundColor(index == selectedSource ? .white : XingGuangTheme.text)
                                    .padding(.horizontal, 14)
                                    .frame(height: 38)
                                    .background(index == selectedSource ? XingGuangTheme.primary : XingGuangTheme.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var groupPicker: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "分组")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                            Button {
                                selectedGroup = index
                            } label: {
                                Text(group.name)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedGroup == index ? .white : XingGuangTheme.text)
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(selectedGroup == index ? XingGuangTheme.primary : XingGuangTheme.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var channelGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "频道")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 240), spacing: 12)], spacing: 12) {
                ForEach(Array(channels.enumerated()), id: \.offset) { index, channel in
                    Button {
                        selectedChannel = index
                        selectedLine = 0
                        attemptedLines = []
                        playCurrent(channel: channel, line: 0)
                    } label: {
                        HStack(spacing: 10) {
                            Text(channel.number)
                                .font(.caption.weight(.bold))
                                .foregroundColor(selectedChannel == index ? .white : XingGuangTheme.primary)
                                .frame(width: 34, height: 30)
                                .background(selectedChannel == index ? XingGuangTheme.primary : XingGuangTheme.panelAccent)
                                .clipShape(Circle())
                            Text(channel.name)
                                .font(.body.weight(.medium))
                                .foregroundColor(XingGuangTheme.text)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .xingGuangPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var epgPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "节目单", trailing: currentChannel?.name ?? "")
            if epgDates.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(epgDates, id: \.self) { date in
                            Button {
                                selectedEPGDate = date
                            } label: {
                                Text(date)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(selectedEPGDate == date ? .white : XingGuangTheme.text)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(selectedEPGDate == date ? XingGuangTheme.primary : XingGuangTheme.panelAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if epgLoading {
                ProgressView("正在加载节目单")
            } else if !epgError.isEmpty {
                Text(epgError).font(.subheadline).foregroundColor(.red)
            } else if currentEPG.isEmpty {
                Text("暂无节目单").font(.subheadline).foregroundColor(XingGuangTheme.secondaryText)
            } else {
                ForEach(Array(currentEPG.prefix(8)), id: \.id) { item in
                    Button { playCurrent(programme: item) } label: {
                        HStack(spacing: 14) {
                            Text(item.start)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(isCurrent(item) ? XingGuangTheme.primary : XingGuangTheme.secondaryText)
                            Text(item.title.isEmpty ? "未命名节目" : item.title)
                                .font(.body.weight(isCurrent(item) ? .semibold : .regular))
                                .foregroundColor(XingGuangTheme.text)
                                .lineLimit(1)
                            Spacer()
                            if canReplay(item) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundColor(XingGuangTheme.primary)
                                    .accessibilityLabel("回看")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .xingGuangPanel()
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

    private func resetSelection(keepSource: Bool = false) {
        if !keepSource { selectedSource = min(selectedSource, max(model.liveSources.count - 1, 0)) }
        selectedGroup = 0
        selectedChannel = 0
        selectedLine = 0
        epg = []
        selectedEPGDate = ""
        attemptedLines = []
        playbackError = ""
        playbackNotice = ""
        session.stop()
        loadEPG()
    }

    private func playCurrent(programme: EpgData? = nil, channel: Channel? = nil, line: Int? = nil) {
        guard let source, let channel = channel ?? currentChannel else { return }
        let playbackLine = line ?? selectedLine
        do {
            let request = try model.livePlaybackRequest(live: source, channel: channel, line: playbackLine, programme: programme)
            playbackError = ""
            playbackNotice = ""
            attemptedLines.insert(playbackLine)
            session.load(request)
        } catch {
            playbackError = error.localizedDescription
        }
    }

    private func canReplay(_ programme: EpgData) -> Bool {
        guard let source, let channel = currentChannel,
              channel.catchup != nil || source.catchup != nil,
              channel.urls.indices.contains(selectedLine) else { return false }
        let raw = channel.urls[selectedLine].split(separator: "$", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let catchup = channel.catchup ?? source.catchup
        return catchup?.replayURL(
            baseURL: raw,
            programme: programme,
            timeZone: TimeZone(identifier: source.timeZone) ?? .current
        ) != nil
    }

    private func loadEPG() {
        guard let source, let channel = currentChannel else { epg = []; return }
        epgTask?.cancel()
        epgLoading = true
        epgError = ""
        epgTask = Task {
            do {
                let value = try await model.loadEPG(for: source, channel: channel)
                guard !Task.isCancelled else { return }
                epg = value
                let dates = Array(Set(value.map(\.date).filter { !$0.isEmpty })).sorted()
                if !dates.contains(selectedEPGDate) { selectedEPGDate = dates.first ?? "" }
                epgLoading = false
            } catch is CancellationError {
            } catch {
                epgLoading = false
                epgError = error.localizedDescription
            }
        }
    }

    private func isCurrent(_ item: EpgData) -> Bool {
        let now = DateFormatter()
        now.dateFormat = "HH:mm"
        let value = now.string(from: Date())
        guard !item.start.isEmpty else { return false }
        if item.end.isEmpty { return value >= item.start }
        return value >= item.start && value < item.end
    }

    private func handlePlaybackState(_ state: PlayerState) {
        guard model.automaticLineChange,
              case .failed(let failure) = state,
              failure.category == .network || failure.category == .format || failure.category == .decoding,
              let channel = currentChannel else { return }
        let next = selectedLine + 1
        guard channel.urls.indices.contains(next), !attemptedLines.contains(next) else { return }
        lineFallbackTask?.cancel()
        lineFallbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            selectedLine = next
            playCurrent(line: next)
            playbackNotice = "已自动切换到 \(lineTitle(channel.urls[next], index: next))"
        }
    }

    private func lineTitle(_ value: String, index: Int) -> String {
        let parts = value.split(separator: "$", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let name = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return "线路 \(index + 1)"
    }
}

struct LiveHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LiveHomeView(model: XingGuangAppModel())
        }
    }
}
