import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var model: XingGuangAppModel
    @State private var isImportingBackup = false
    @State private var isExportingBackup = false
    @State private var exportDocument: BackupFileDocument?
    @State private var exportFileName = "tv-backup.bk.gz"
    @State private var backupImportState: BackupImportState = .idle
    @State private var backupExportState: BackupExportState = .idle
    @State private var isImportingConfiguration = false
    @State private var configurationKind: ConfigurationKind?
    @State private var scannerKind: ConfigurationKind?
    @State private var configurationImportState: ConfigurationImportState = .idle
    @State private var isImportingLocalMedia = false
    @State private var localMediaFile: LocalMediaFile?
    @State private var localMediaError = ""
    @State private var localMediaLoading = false
    @State private var cacheSizeText = "计算中"
    @State private var cacheError = ""
    @State private var cacheIsWorking = false

    private let backupDestination: (any BackupDocumentApplying)?
    private let backupImportService: BackupImportService
    private let backupExportService: BackupExportService
    private let configurationImportService: ConfigurationImportService
    private let localMediaImportService: LocalMediaImportService
    private let cacheManagementService: CacheManagementService

    public init(
        model: XingGuangAppModel,
        backupDestination: (any BackupDocumentApplying)? = nil,
        backupImportService: BackupImportService = BackupImportService(),
        backupExportService: BackupExportService = BackupExportService(),
        configurationImportService: ConfigurationImportService = ConfigurationImportService(),
        localMediaImportService: LocalMediaImportService = LocalMediaImportService(),
        cacheManagementService: CacheManagementService = CacheManagementService()
    ) {
        self.model = model
        self.backupDestination = backupDestination
        self.backupImportService = backupImportService
        self.backupExportService = backupExportService
        self.configurationImportService = configurationImportService
        self.localMediaImportService = localMediaImportService
        self.cacheManagementService = cacheManagementService
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                configurationPanel(
                    title: "点播配置",
                    systemName: "film",
                    placeholder: "https://example.com/vod.json",
                    value: $model.vodConfigURL,
                    kind: .vod
                )
                configurationPanel(
                    title: "直播配置",
                    systemName: "play.tv",
                    placeholder: "https://example.com/live.json",
                    value: $model.liveConfigURL,
                    kind: .live
                )

                Button {
                    model.saveConfiguration()
                } label: {
                    Label("保存配置", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(XingGuangTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("settings.save")

                configurationStatus
                configurationImportStatus

                VStack(alignment: .leading, spacing: 10) {
                    Label("播放内核", systemImage: "play.rectangle")
                        .font(.headline)
                        .foregroundColor(XingGuangTheme.text)
                    Picker("播放内核", selection: $model.playerPreference) {
                        Text("MPV").tag(PlayerEnginePreference.mpv)
                        Text("MDK").tag(PlayerEnginePreference.mdk)
                        Text("AVPlayer").tag(PlayerEnginePreference.avPlayer)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .xingGuangPanel()

                VStack(spacing: 0) {
                    Button {
                        localMediaError = ""
                        isImportingLocalMedia = true
                    } label: {
                        settingsRow(title: "打开本地媒体", value: "选择文件", systemName: "folder.badge.play")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.localMedia.open")

                    if localMediaLoading {
                        Label("正在准备本地媒体", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(XingGuangTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                    } else if !localMediaError.isEmpty {
                        Label(localMediaError, systemImage: "xmark.octagon.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .accessibilityIdentifier("settings.localMedia.failed")
                    }

                    Divider().padding(.leading, 48)

                    Button {
                        clearCache()
                    } label: {
                        settingsRow(
                            title: "缓存",
                            value: cacheIsWorking ? "正在清理" : cacheSizeText,
                            systemName: "trash"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(cacheIsWorking)
                    .accessibilityIdentifier("settings.cache.clear")

                    if !cacheError.isEmpty {
                        Label(cacheError, systemImage: "xmark.octagon.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                    }

                    Divider().padding(.leading, 48)

                    NavigationLink(destination: PlayerSettingsPreviewView(model: model)) {
                        settingsRow(title: "播放器设置", value: "进入", systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 48)

                    Toggle(isOn: $model.incognito) {
                        settingsLabel(title: "隐身模式", systemName: "eye.slash")
                    }
                    .tint(XingGuangTheme.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)

                    Divider().padding(.leading, 48)

                    Toggle(isOn: $model.automaticLineChange) {
                        settingsLabel(title: "直播自动换线", systemName: "arrow.triangle.2.circlepath")
                    }
                    .tint(XingGuangTheme.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)

                    Divider().padding(.leading, 48)

                    HStack(spacing: 0) {
                        Button {
                            isImportingBackup = true
                        } label: {
                            settingsCommand(title: "导入备份", systemName: "square.and.arrow.down")
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("settings.backupRestore.import")

                        Divider().frame(height: 30)

                        Button {
                            startBackupExport()
                        } label: {
                            settingsCommand(title: "导出备份", systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("settings.backupRestore.export")
                    }
                    .frame(minHeight: 52)
                    .accessibilityIdentifier("settings.backupRestore")

                    backupImportStatus
                    backupExportStatus

                    Divider().padding(.leading, 48)

                    HStack(spacing: 10) {
                        settingsLabel(title: "版本", systemName: "info.circle")
                        Spacer()
                        Text(appVersionText)
                            .font(.subheadline)
                            .foregroundColor(XingGuangTheme.secondaryText)
                            .accessibilityIdentifier("settings.version.value")
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                }
                .xingGuangPanel()
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshCacheSize() }
        .onChange(of: model.vodConfigURL) { _ in model.resetConfigurationSaveState() }
        .onChange(of: model.liveConfigURL) { _ in model.resetConfigurationSaveState() }
        .fileImporter(
            isPresented: $isImportingLocalMedia,
            allowedContentTypes: LocalMediaImportService.contentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleLocalMediaSelection
        )
        .fileImporter(
            isPresented: $isImportingConfiguration,
            allowedContentTypes: configurationContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleConfigurationSelection
        )
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: backupContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleBackupSelection
        )
        .fileExporter(
            isPresented: $isExportingBackup,
            document: exportDocument,
            contentType: backupGzipType,
            defaultFilename: exportFileName,
            onCompletion: handleBackupExport
        )
        .sheet(item: $scannerKind) { kind in
            QRCodeScannerSheet(
                onResult: { handleScannedConfiguration($0, kind: kind) },
                onCancel: { scannerKind = nil }
            )
        }
        .sheet(item: $localMediaFile) { file in
            LocalMediaPlayerView(file: file, model: model)
        }
        .accessibilityIdentifier("settings.home")
    }

    private var configurationContentTypes: [UTType] {
        [.json, .plainText, .data]
    }

    private var backupContentTypes: [UTType] {
        var types: [UTType] = [.json, .data]
        if let gzip = UTType(filenameExtension: "gz") {
            types.insert(gzip, at: 0)
        }
        return types
    }

    private var backupGzipType: UTType {
        UTType(filenameExtension: "gz") ?? .data
    }

    private func handleLocalMediaSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { localMediaError = error.localizedDescription }
            return
        }

        localMediaLoading = true
        localMediaError = ""
        let accessed = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
                localMediaLoading = false
            }
            do {
                localMediaFile = try await localMediaImportService.importFile(at: url)
            } catch {
                localMediaError = error.localizedDescription
            }
        }
    }

    private func refreshCacheSize() {
        Task {
            let bytes = await cacheManagementService.size()
            cacheSizeText = bytes == 0 ? "无" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    private func clearCache() {
        cacheIsWorking = true
        cacheError = ""
        Task {
            defer { cacheIsWorking = false }
            do {
                try await cacheManagementService.clear()
                cacheSizeText = "无"
            } catch {
                cacheError = "缓存清理失败：\(error.localizedDescription)"
                refreshCacheSize()
            }
        }
    }

    @ViewBuilder
    private var backupImportStatus: some View {
        switch backupImportState {
        case .idle:
            EmptyView()
        case .loading:
            Label("正在导入备份", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundColor(XingGuangTheme.secondaryText)
                .padding(.horizontal, 14)
        case .success:
            Label("备份已导入", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.green)
                .padding(.horizontal, 14)
                .accessibilityIdentifier("settings.backupRestore.success")
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .accessibilityIdentifier("settings.backupRestore.failed")
        }
    }

    @ViewBuilder
    private var backupExportStatus: some View {
        switch backupExportState {
        case .idle:
            EmptyView()
        case .loading:
            Label("正在准备备份", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundColor(XingGuangTheme.secondaryText)
                .padding(.horizontal, 14)
        case .success:
            Label("备份已导出", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.green)
                .padding(.horizontal, 14)
                .accessibilityIdentifier("settings.backupExport.success")
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .accessibilityIdentifier("settings.backupExport.failed")
        }
    }

    private func handleBackupSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                backupImportState = .failed(error.localizedDescription)
            }
            return
        }

        backupImportState = .loading
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            // Decode before opening the live database so malformed input
            // cannot even create or migrate the persistence store.
            let backup = try backupImportService.decode(data)
            let destination: any BackupDocumentApplying
            if let backupDestination {
                destination = backupDestination
            } else {
                destination = try AppDatabase.live()
            }
            try destination.replaceAll(with: backup)
            refreshModel(using: backup.document)
            backupImportState = .success
        } catch {
            backupImportState = .failed(error.localizedDescription)
        }
    }

    private func handleConfigurationSelection(_ result: Result<[URL], Error>) {
        guard let kind = configurationKind else { return }
        defer { configurationKind = nil }
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                configurationImportState = .failed(error.localizedDescription)
            }
            return
        }

        configurationImportState = .loading
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let importedURL = try configurationImportService.importFile(at: url, kind: kind)
            applyConfigurationAddress(importedURL.absoluteString, kind: kind)
            configurationImportState = .success(kind)
        } catch {
            configurationImportState = .failed(error.localizedDescription)
        }
    }

    private func handleScannedConfiguration(_ value: String, kind: ConfigurationKind) {
        do {
            let url = try configurationImportService.scannedAddress(value)
            scannerKind = nil
            applyConfigurationAddress(url.absoluteString, kind: kind)
            configurationImportState = .success(kind)
        } catch {
            scannerKind = nil
            configurationImportState = .failed(error.localizedDescription)
        }
    }

    private func applyConfigurationAddress(_ value: String, kind: ConfigurationKind) {
        switch kind {
        case .vod: model.vodConfigURL = value
        case .live: model.liveConfigURL = value
        }
        model.saveConfiguration()
    }

    private func startBackupExport() {
        backupExportState = .loading
        do {
            let artifact = try backupExportService.artifact(for: model.makeBackupDocument())
            exportDocument = BackupFileDocument(data: artifact.data)
            exportFileName = artifact.suggestedFileName
            isExportingBackup = true
        } catch {
            backupExportState = .failed(error.localizedDescription)
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupExportState = .success
        case .failure(let error):
            backupExportState = .failed(error.localizedDescription)
        }
    }

    private func refreshModel(using document: BackupDocument) {
        let vodURL = latestConfiguration(in: document, type: 0)?.url ?? ""
        let liveURL = latestConfiguration(in: document, type: 1)?.url ?? ""
        model.vodConfigURL = vodURL
        model.liveConfigURL = liveURL
        UserDefaults.standard.set(vodURL, forKey: "ios.vodConfigURL")
        UserDefaults.standard.set(liveURL, forKey: "ios.liveConfigURL")
        model.reloadPreferences()
        model.bootstrap()
    }

    private func latestConfiguration(in document: BackupDocument, type: Int) -> ConfigRecord? {
        document.configs
            .filter { $0.type == type }
            .max { $0.time < $1.time }
    }

    private func configurationPanel(
        title: String,
        systemName: String,
        placeholder: String,
        value: Binding<String>,
        kind: ConfigurationKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemName)
                .font(.headline)
                .foregroundColor(XingGuangTheme.text)
            HStack(spacing: 8) {
                TextField(placeholder, text: value)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityLabel(title)
                Button {
                    configurationKind = kind
                    isImportingConfiguration = true
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("导入\(title)文件")
                .accessibilityIdentifier("settings.\(kind.rawValue).file")
                Button {
                    scannerKind = kind
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("扫描\(title)二维码")
                .accessibilityIdentifier("settings.\(kind.rawValue).scan")
            }
        }
        .padding(14)
        .xingGuangPanel()
    }

    @ViewBuilder
    private var configurationStatus: some View {
        switch model.configurationSaveState {
        case .idle:
            EmptyView()
        case .loading:
            Label("正在加载配置", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundColor(XingGuangTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .saved:
            Label("配置已保存", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.saved")
        case .invalid:
            Label("配置地址格式不正确", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.invalid")
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var configurationImportStatus: some View {
        switch configurationImportState {
        case .idle:
            EmptyView()
        case .loading:
            Label("正在导入配置", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
                .foregroundColor(XingGuangTheme.secondaryText)
        case .success(let kind):
            Label(kind == .vod ? "点播配置已导入" : "直播配置已导入", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.green)
                .accessibilityIdentifier("settings.configurationImport.success")
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red)
                .accessibilityIdentifier("settings.configurationImport.failed")
        }
    }

    private func settingsLabel(title: String, systemName: String) -> some View {
        Label {
            Text(title)
                .foregroundColor(XingGuangTheme.text)
        } icon: {
            Image(systemName: systemName)
                .foregroundColor(XingGuangTheme.primary)
                .frame(width: 24)
        }
    }

    private func settingsRow(title: String, value: String, systemName: String) -> some View {
        HStack(spacing: 10) {
            settingsLabel(title: title, systemName: systemName)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(XingGuangTheme.secondaryText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(XingGuangTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func settingsCommand(title: String, systemName: String) -> some View {
        Label(title, systemImage: systemName)
            .font(.subheadline.weight(.medium))
            .foregroundColor(XingGuangTheme.text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
    }

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "未知"
        let build = info["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

private enum BackupImportState: Equatable {
    case idle
    case loading
    case success
    case failed(String)
}

private enum BackupExportState: Equatable {
    case idle
    case loading
    case success
    case failed(String)
}

private enum ConfigurationImportState: Equatable {
    case idle
    case loading
    case success(ConfigurationKind)
    case failed(String)
}

private struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "gz") ?? .data, .json, .data] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct PlayerSettingsPreviewView: View {
    @ObservedObject var model: XingGuangAppModel

    var body: some View {
        Form {
            Section("播放") {
                HStack {
                    Text("播放内核")
                    Spacer()
                    Text(playerEngineTitle)
                        .foregroundColor(.secondary)
                }
                Toggle("直播自动换线", isOn: $model.automaticLineChange)
                Picker("默认画面比例", selection: $model.defaultAspectMode) {
                    ForEach(PlayerAspectMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("直播画面比例", selection: $model.liveAspectMode) {
                    ForEach(PlayerAspectMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("速度") {
                Slider(value: $model.defaultPlaybackSpeed, in: 0.5...2.0, step: 0.25)
                Text("\(model.defaultPlaybackSpeed, specifier: "%.2g")x")
                    .foregroundColor(XingGuangTheme.primary)
            }

            Section("字幕") {
                Slider(value: $model.subtitleTextSize, in: 14...42, step: 1)
                Text("字号 \(Int(model.subtitleTextSize))")
                    .foregroundColor(XingGuangTheme.primary)
                Slider(value: $model.subtitleBottomOffset, in: 8...120, step: 4)
                Text("底部位置 \(Int(model.subtitleBottomOffset))")
                    .foregroundColor(XingGuangTheme.primary)
            }

            Section("弹幕") {
                Toggle("显示弹幕", isOn: $model.danmakuEnabled)
            }

            Section("网络") {
                TextField("User-Agent", text: $model.globalUserAgent)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings.player.userAgent")
            }
        }
        .navigationTitle("播放器设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playerEngineTitle: String {
        switch model.playerPreference {
        case .mpv: return "MPV"
        case .mdk: return "MDK"
        case .avPlayer: return "AVPlayer"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(model: XingGuangAppModel())
        }
    }
}
