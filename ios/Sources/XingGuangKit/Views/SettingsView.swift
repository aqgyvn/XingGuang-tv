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
    @State private var configurationPendingDeletion: ConfigRecord?
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
            LazyVStack(alignment: .leading, spacing: 16) {
                sourceSettingsPanel
                playbackSettingsPanel
                storageSettingsPanel
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
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
        .alert(item: $configurationPendingDeletion) { record in
            Alert(
                title: Text("删除配置记录？"),
                message: Text(record.url),
                primaryButton: .destructive(Text("删除")) {
                    _ = model.deleteConfiguration(record)
                },
                secondaryButton: .cancel()
            )
        }
        .accessibilityIdentifier("settings.home")
    }

    private var sourceSettingsPanel: some View {
        VStack(spacing: 16) {
            configurationSourceCard(for: .vod)
            configurationSourceCard(for: .live)
        }
    }

    private var playbackSettingsPanel: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: PlayerSettingsPreviewView(model: model)) {
                settingsRow(
                    title: "播放器设置",
                    value: playerEngineTitle,
                    systemName: "slider.horizontal.3"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.player.open")
            .xingGuangPanel()

            Toggle(isOn: $model.incognito) {
                settingsLabel(title: "无痕模式", systemName: "eye.slash")
            }
            .tint(XingGuangTheme.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .accessibilityIdentifier("settings.incognito")
            .xingGuangPanel()

            Menu {
                ForEach(CatalogDisplaySize.allCases) { size in
                    Button {
                        model.catalogDisplaySize = size
                    } label: {
                        Label(size.title, systemImage: size == model.catalogDisplaySize ? "checkmark" : "rectangle.grid.2x2")
                    }
                }
            } label: {
                settingsRow(
                    title: "图片尺寸",
                    value: model.catalogDisplaySize.title,
                    systemName: "rectangle.grid.2x2"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.catalogDisplaySize")
            .xingGuangPanel()

            settingsRow(title: "DNS", value: "跟随系统", systemName: "globe", showsDisclosure: false)
                .xingGuangPanel()
        }
    }

    private var storageSettingsPanel: some View {
        VStack(spacing: 16) {
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
            .xingGuangPanel()

            VStack(spacing: 0) {
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
            }
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
                        .padding(.bottom, 12)
                } else if !localMediaError.isEmpty {
                    Label(localMediaError, systemImage: "xmark.octagon.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("settings.localMedia.failed")
                }
            }
            .xingGuangPanel()

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
            .xingGuangPanel()

            if !cacheError.isEmpty {
                Label(cacheError, systemImage: "xmark.octagon.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
            }
        }
    }

    private func configurationSourceCard(for kind: ConfigurationKind) -> some View {
        HStack(spacing: 4) {
            NavigationLink(destination: configurationEditor(for: kind)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(configurationTitle(for: kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.text)
                    Text(configurationSummary(configurationURL(for: kind)))
                        .font(.caption)
                        .foregroundColor(XingGuangTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.\(kind.rawValue).open")

            configurationHomeMenu(for: kind)

            NavigationLink(destination: configurationHistoryScreen(for: kind)) {
                ActionIcon(
                    systemName: "clock.arrow.circlepath",
                    label: "\(configurationTitle(for: kind))历史"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.\(kind.rawValue).history")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .xingGuangPanel()
    }

    @ViewBuilder
    private func configurationHomeMenu(for kind: ConfigurationKind) -> some View {
        switch kind {
        case .vod:
            Menu {
                ForEach(visibleSites) { site in
                    Button {
                        model.selectSite(site)
                    } label: {
                        Label(site.name, systemImage: site.key == model.selectedSite.key ? "checkmark" : "house")
                    }
                }
            } label: {
                ActionIcon(systemName: "house", label: "选择点播主页")
            }
            .buttonStyle(.plain)
            .disabled(!canChangeVodHome)
            .accessibilityIdentifier("settings.vod.home")
        case .live:
            Menu {
                ForEach(model.liveSources.indices, id: \.self) { index in
                    let source = model.liveSources[index]
                    Button {
                        model.selectLiveSource(source)
                    } label: {
                        Label(source.name, systemImage: source.name == model.selectedLiveSourceName ? "checkmark" : "tv")
                    }
                }
            } label: {
                ActionIcon(systemName: "house", label: "选择直播主页")
            }
            .buttonStyle(.plain)
            .disabled(!canChangeLiveHome)
            .accessibilityIdentifier("settings.live.home")
        }
    }

    private var canChangeVodHome: Bool {
        visibleSites.count > 1 && model.selectedSite.changeable != 0
    }

    private var canChangeLiveHome: Bool {
        model.liveSources.count > 1
    }

    private func configurationHistoryScreen(for kind: ConfigurationKind) -> some View {
        ScrollView {
            configurationHistoryPanel(for: kind)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("\(configurationTitle(for: kind))历史")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.\(kind.rawValue).history.screen")
    }

    private func configurationTitle(for kind: ConfigurationKind) -> String {
        kind == .vod ? "点播配置" : "直播配置"
    }

    private func configurationURL(for kind: ConfigurationKind) -> String {
        kind == .vod ? model.vodConfigURL : model.liveConfigURL
    }

    private func configurationEditor(for kind: ConfigurationKind) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch kind {
                case .vod:
                    configurationPanel(
                        title: "点播配置",
                        systemName: "film",
                        placeholder: "https://example.com/vod.json",
                        value: $model.vodConfigURL,
                        kind: .vod
                    )
                case .live:
                    configurationPanel(
                        title: "直播配置",
                        systemName: "play.tv",
                        placeholder: "https://example.com/live.json",
                        value: $model.liveConfigURL,
                        kind: .live
                    )
                }

                Button {
                    model.saveConfiguration(kind)
                } label: {
                    Label("保存并加载", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(XingGuangTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("settings.save")

                configurationStatus
                configurationImportStatus
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle(kind == .vod ? "点播配置" : "直播配置")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.\(kind.rawValue).editor")
    }

    private var visibleSites: [Site] {
        model.configuration.sites.filter { $0.hide != 1 && !$0.key.isEmpty }
    }

    private var playerEngineTitle: String {
        switch model.playerPreference {
        case .mpv: return "MPV"
        case .mdk: return "MDK"
        case .avPlayer: return "AVPlayer"
        }
    }

    private func configurationSummary(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "未配置" }
        return trimmed.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
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

    private func configurationHistoryPanel(for kind: ConfigurationKind) -> some View {
        let records = model.configurationHistory.filter { $0.type == configurationType(for: kind) }
        return VStack(alignment: .leading, spacing: 0) {
            if records.isEmpty {
                Text("暂无配置记录")
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { Divider().padding(.leading, 48) }
                    configurationHistoryRow(record)
                }
            }

            if !model.configurationHistoryError.isEmpty {
                Label(model.configurationHistoryError, systemImage: "xmark.octagon.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .xingGuangPanel()
        .accessibilityIdentifier("settings.configurationHistory")
    }

    private func configurationHistoryRow(_ record: ConfigRecord) -> some View {
        let isCurrent = model.isCurrentConfiguration(record)
        let title = record.name.isEmpty ? (record.type == 0 ? "点播配置" : "直播配置") : record.name
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.type == 0 ? "film" : "play.tv")
                .foregroundColor(XingGuangTheme.primary)
                .frame(width: 24, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.text)
                    if isCurrent {
                        Text("当前使用")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                }
                Text(record.url)
                    .font(.caption)
                    .foregroundColor(XingGuangTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(configurationUpdatedText(record.time))
                    .font(.caption)
                    .foregroundColor(XingGuangTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.activateConfiguration(record)
            } label: {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .disabled(isCurrent)
            .accessibilityLabel(isCurrent ? "当前配置" : "切换配置")
            .accessibilityIdentifier("settings.configurationHistory.activate.\(record.id)")

            Button {
                configurationPendingDeletion = record
            } label: {
                Image(systemName: "trash")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .foregroundColor(isCurrent ? XingGuangTheme.secondaryText : .red)
            .disabled(isCurrent)
            .accessibilityLabel(isCurrent ? "当前配置不可删除" : "删除配置")
            .accessibilityIdentifier("settings.configurationHistory.delete.\(record.id)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func configurationType(for kind: ConfigurationKind) -> Int {
        kind == .vod ? 0 : 1
    }

    private func configurationUpdatedText(_ milliseconds: Int64) -> String {
        guard milliseconds > 0 else { return "更新时间未知" }
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        return "更新于 \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))"
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

    private func settingsRow(
        title: String,
        value: String,
        systemName: String,
        showsDisclosure: Bool = true
    ) -> some View {
        HStack(spacing: 10) {
            settingsLabel(title: title, systemName: systemName)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(XingGuangTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.middle)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(XingGuangTheme.secondaryText)
            }
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                playbackPanel
                timedTextPanel
                networkPanel
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("播放器设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playbackPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                playerLabel(title: "播放内核", systemName: "play.rectangle")
                Picker("播放内核", selection: $model.playerPreference) {
                    Text("MPV").tag(PlayerEnginePreference.mpv)
                    Text("MDK").tag(PlayerEnginePreference.mdk)
                    Text("AVPlayer").tag(PlayerEnginePreference.avPlayer)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.player.engine")
            }
            .padding(14)
            .xingGuangPanel()

            Toggle(isOn: $model.automaticLineChange) {
                playerLabel(title: "直播自动换线", systemName: "arrow.triangle.2.circlepath")
            }
            .tint(XingGuangTheme.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .xingGuangPanel()

            pickerRow(title: "默认画面比例", systemName: "rectangle.expand.vertical", selection: $model.defaultAspectMode)
                .xingGuangPanel()

            pickerRow(title: "直播画面比例", systemName: "tv", selection: $model.liveAspectMode)
                .xingGuangPanel()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    playerLabel(title: "默认倍速", systemName: "speedometer")
                    Spacer()
                    Text("\(model.defaultPlaybackSpeed, specifier: "%.2g")x")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.primary)
                }
                Slider(value: $model.defaultPlaybackSpeed, in: 0.5...2.0, step: 0.25)
                    .tint(XingGuangTheme.primary)
            }
            .padding(14)
            .xingGuangPanel()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    playerLabel(title: "长按倍速", systemName: "hand.tap")
                    Spacer()
                    Text("\(model.longPressPlaybackSpeed, specifier: "%.2g")x")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.primary)
                }
                Slider(value: $model.longPressPlaybackSpeed, in: 2...5, step: 0.25)
                    .tint(XingGuangTheme.primary)
                    .accessibilityIdentifier("settings.player.longPressSpeed")
            }
            .padding(14)
            .xingGuangPanel()
        }
    }

    private var timedTextPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    playerLabel(title: "字幕字号", systemName: "textformat.size")
                    Spacer()
                    Text("\(Int(model.subtitleTextSize))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.primary)
                }
                Slider(value: $model.subtitleTextSize, in: 14...42, step: 1)
                    .tint(XingGuangTheme.primary)
            }
            .padding(14)
            .xingGuangPanel()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    playerLabel(title: "字幕底部位置", systemName: "text.alignleft")
                    Spacer()
                    Text("\(Int(model.subtitleBottomOffset))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.primary)
                }
                Slider(value: $model.subtitleBottomOffset, in: 8...120, step: 4)
                    .tint(XingGuangTheme.primary)
            }
            .padding(14)
            .xingGuangPanel()

            Toggle(isOn: $model.danmakuLoadEnabled) {
                playerLabel(title: "加载弹幕", systemName: "arrow.down.circle")
            }
            .tint(XingGuangTheme.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .accessibilityIdentifier("settings.player.danmakuLoad")
            .xingGuangPanel()

            Toggle(isOn: $model.danmakuEnabled) {
                playerLabel(title: "显示弹幕", systemName: "text.bubble")
            }
            .tint(XingGuangTheme.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .xingGuangPanel()
        }
    }

    private var networkPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                playerLabel(title: "User-Agent", systemName: "network")
                TextField("未填写时使用来源配置", text: $model.globalUserAgent)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings.player.userAgent")
            }
            .padding(14)
            .xingGuangPanel()

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $model.adHostBlockingEnabled) {
                    playerLabel(title: "广告主机拦截", systemName: "shield.lefthalf.filled")
                }
                .tint(XingGuangTheme.primary)
                Text("对 App 请求和网页嗅探生效")
                    .font(.caption)
                    .foregroundColor(XingGuangTheme.secondaryText)
                    .padding(.leading, 34)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityIdentifier("settings.player.adHostBlocking")
            .xingGuangPanel()

            HStack(spacing: 10) {
                playerLabel(title: "DNS", systemName: "globe")
                Spacer()
                Text("跟随系统")
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .xingGuangPanel()
        }
    }

    private func pickerRow(
        title: String,
        systemName: String,
        selection: Binding<PlayerAspectMode>
    ) -> some View {
        HStack(spacing: 10) {
            playerLabel(title: title, systemName: systemName)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(PlayerAspectMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(XingGuangTheme.primary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    private func playerLabel(title: String, systemName: String) -> some View {
        Label {
            Text(title)
                .foregroundColor(XingGuangTheme.text)
        } icon: {
            Image(systemName: systemName)
                .foregroundColor(XingGuangTheme.primary)
                .frame(width: 24)
        }
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
