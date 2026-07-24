import SwiftUI

public struct SettingsView: View {
    @ObservedObject var model: XingGuangAppModel
    @State private var incognito = false
    @State private var automaticDanmaku = true

    public init(model: XingGuangAppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                configurationPanel(
                    title: "点播配置",
                    systemName: "film",
                    placeholder: "https://example.com/vod.json",
                    value: $model.vodConfigURL
                )
                configurationPanel(
                    title: "直播配置",
                    systemName: "play.tv",
                    placeholder: "https://example.com/live.json",
                    value: $model.liveConfigURL
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

                VStack(alignment: .leading, spacing: 10) {
                    Label("播放内核", systemImage: "play.rectangle")
                        .font(.headline)
                        .foregroundColor(XingGuangTheme.text)
                    Picker("播放内核", selection: $model.playerPreference) {
                        Text("自动").tag(PlayerEnginePreference.automatic)
                        Text("AVPlayer").tag(PlayerEnginePreference.avPlayer)
                        Text("VLC").tag(PlayerEnginePreference.vlc)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .xingGuangPanel()

                VStack(spacing: 0) {
                    NavigationLink(destination: PlayerSettingsPreviewView()) {
                        settingsRow(title: "播放器设置", value: "进入", systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 48)

                    Toggle(isOn: $incognito) {
                        settingsLabel(title: "隐身模式", systemName: "eye.slash")
                    }
                    .tint(XingGuangTheme.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)

                    Divider().padding(.leading, 48)

                    Toggle(isOn: $automaticDanmaku) {
                        settingsLabel(title: "自动加载弹幕", systemName: "text.bubble")
                    }
                    .tint(XingGuangTheme.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)

                    Divider().padding(.leading, 48)

                    settingsRow(title: "备份与恢复", value: "管理", systemName: "externaldrive")
                }
                .xingGuangPanel()
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.vodConfigURL) { _ in model.resetConfigurationSaveState() }
        .onChange(of: model.liveConfigURL) { _ in model.resetConfigurationSaveState() }
        .accessibilityIdentifier("settings.home")
    }

    private func configurationPanel(
        title: String,
        systemName: String,
        placeholder: String,
        value: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemName)
                .font(.headline)
                .foregroundColor(XingGuangTheme.text)
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel(title)
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
}

private struct PlayerSettingsPreviewView: View {
    @State private var automaticLineChange = true
    @State private var subtitles = true
    @State private var backgroundPlayback = false
    @State private var speed = 1.0

    var body: some View {
        Form {
            Section("播放") {
                HStack {
                    Text("播放内核")
                    Spacer()
                    Text("AVPlayer")
                        .foregroundColor(.secondary)
                }
                Toggle("自动换线", isOn: $automaticLineChange)
                Toggle("字幕", isOn: $subtitles)
                Toggle("后台播放", isOn: $backgroundPlayback)
            }

            Section("速度") {
                Slider(value: $speed, in: 0.5...2.0, step: 0.25)
                Text("\(speed, specifier: "%.2g")x")
                    .foregroundColor(XingGuangTheme.primary)
            }
        }
        .navigationTitle("播放器设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(model: XingGuangAppModel())
        }
    }
}
