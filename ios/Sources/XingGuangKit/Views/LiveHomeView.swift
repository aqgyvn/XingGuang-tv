import SwiftUI

public struct LiveHomeView: View {
    @ObservedObject var model: XingGuangAppModel
    @State private var selectedGroup = 0
    @State private var selectedChannel = 0

    public init(model: XingGuangAppModel) {
        self.model = model
    }

    private var source: Live? {
        model.liveSources.first
    }

    private var groups: [LiveGroup] {
        source?.groups ?? []
    }

    private var channels: [Channel] {
        guard groups.indices.contains(selectedGroup) else { return [] }
        return groups[selectedGroup].channels
    }

    private var currentChannel: Channel? {
        guard channels.indices.contains(selectedChannel) else { return channels.first }
        return channels[selectedChannel]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                playerPreview
                groupPicker
                channelGrid
                epgPreview
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle("直播")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("live.home")
    }

    private var playerPreview: some View {
        ZStack(alignment: .bottomLeading) {
            XingGuangTheme.playerBackground
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 48))
                        .foregroundColor(XingGuangTheme.primary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(currentChannel?.name ?? "暂无频道")
                    .font(.headline)
                Text(source?.name ?? "未配置直播")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.72))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var groupPicker: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "分组")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            Button {
                                selectedGroup = index
                                selectedChannel = 0
                            } label: {
                                Text(group.name)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedGroup == index ? .white : XingGuangTheme.text)
                                    .padding(.horizontal, 18)
                                    .frame(height: 40)
                                    .background(selectedGroup == index ? XingGuangTheme.primary : XingGuangTheme.panel)
                                    .clipShape(Capsule())
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128, maximum: 220), spacing: 12)], spacing: 12) {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    Button {
                        selectedChannel = index
                    } label: {
                        HStack(spacing: 10) {
                            Text(channel.number)
                                .font(.caption.weight(.bold))
                                .foregroundColor(selectedChannel == index ? .white : XingGuangTheme.primary)
                                .frame(width: 30, height: 30)
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

    private var epgPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "节目单", trailing: "今天")
            epgRow(time: "20:00", title: "正在播放", active: true)
            epgRow(time: "21:00", title: "下一节目", active: false)
        }
        .padding(14)
        .xingGuangPanel()
    }

    private func epgRow(time: String, title: String, active: Bool) -> some View {
        HStack(spacing: 14) {
            Text(time)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(active ? XingGuangTheme.primary : XingGuangTheme.secondaryText)
            Text(title)
                .font(.body.weight(active ? .semibold : .regular))
                .foregroundColor(XingGuangTheme.text)
            Spacer()
            if active {
                Image(systemName: "waveform")
                    .foregroundColor(XingGuangTheme.primary)
            }
        }
        .frame(minHeight: 34)
    }
}

struct LiveHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LiveHomeView(model: XingGuangAppModel())
        }
    }
}
