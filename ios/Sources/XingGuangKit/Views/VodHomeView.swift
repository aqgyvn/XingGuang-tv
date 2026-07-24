import SwiftUI

public struct VodHomeView: View {
    @ObservedObject var model: XingGuangAppModel
    @State private var searchPresented = false

    public init(model: XingGuangAppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                siteHeader
                continueWatching
                categoryPicker
                catalogContent
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $searchPresented) {
            SearchPreviewView(model: model)
        }
        .accessibilityIdentifier("vod.home")
    }

    private var siteHeader: some View {
        HStack(spacing: 12) {
            Image("PreviewLogo", bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                if model.configuration.sites.count > 1 {
                    Menu {
                        ForEach(model.configuration.sites.filter { $0.hide != 1 }) { site in
                            Button {
                                model.selectSite(site)
                            } label: {
                                Label(site.name, systemImage: site.key == model.selectedSite.key ? "checkmark" : "globe")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(model.selectedSite.name.isEmpty ? "未配置点播" : model.selectedSite.name)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .font(.headline)
                        .foregroundColor(XingGuangTheme.text)
                    }
                } else {
                    Text(model.selectedSite.name.isEmpty ? "未配置点播" : model.selectedSite.name)
                        .font(.headline)
                        .foregroundColor(XingGuangTheme.text)
                }
                Text(model.repositoryAvailable ? "线路优先 · 自动测速 · 片单视图" : "请在设置中添加点播配置")
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                searchPresented = true
            } label: {
                ActionIcon(systemName: "magnifyingglass", label: "搜索")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CollectionPreviewView(title: "收藏", items: model.keeps.map { model.vod(from: $0) }, model: model)) {
                ActionIcon(systemName: "star.fill", label: "收藏")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CollectionPreviewView(title: "历史", items: model.histories.map { model.vod(from: $0) }, model: model)) {
                ActionIcon(systemName: "clock.arrow.circlepath", label: "历史")
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .xingGuangPanel()
    }

    @ViewBuilder
    private var continueWatching: some View {
        if let history = model.continueWatching {
            let vod = model.vod(from: history)
            NavigationLink(destination: VodDetailPreviewView(vod: vod, model: model)) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("继续观看")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(XingGuangTheme.primary)
                    Text(history.vodName)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(XingGuangTheme.text)
                    HStack(spacing: 8) {
                        Text(history.vodRemarks.isEmpty ? "继续播放" : history.vodRemarks)
                        Text("\(Int(max(history.position, 0) / 60000)) 分钟")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(XingGuangTheme.text)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(XingGuangTheme.border)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(XingGuangTheme.panelAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("片库分类")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(XingGuangTheme.text)
                Spacer()
                Text("筛选 / 置顶")
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
            }

            if model.categories.isEmpty {
                Text("配置加载后显示分类")
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.categories) { category in
                            Button {
                                model.selectCategory(category)
                            } label: {
                                Text(category.typeName)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(model.selectedCategory == category ? XingGuangTheme.primary : XingGuangTheme.text)
                                    .padding(.horizontal, 20)
                                    .frame(height: 42)
                                    .background(model.selectedCategory == category ? XingGuangTheme.panelAccent : XingGuangTheme.panel)
                                    .overlay(
                                        Capsule()
                                            .stroke(model.selectedCategory == category ? XingGuangTheme.primary : XingGuangTheme.border, lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch model.catalogState {
        case .loading:
            StatusView(systemName: "arrow.triangle.2.circlepath", title: "正在载入片库")
        case .empty:
            StatusView(systemName: "rectangle.stack", title: model.repositoryAvailable ? "暂无影片" : "请先保存点播配置")
        case .failed(let message):
            StatusView(systemName: "exclamationmark.triangle", title: message)
        case .loaded(let items):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 136, maximum: 190), spacing: 16)], spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, vod in
                    NavigationLink(destination: VodDetailPreviewView(vod: vod, model: model)) {
                        VodPosterCard(vod: vod, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StatusView: View {
    let systemName: String
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 34))
                .foregroundColor(XingGuangTheme.secondaryText)
            Text(title)
                .foregroundColor(XingGuangTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct VodHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView { VodHomeView(model: XingGuangAppModel()) }
            NavigationView { VodHomeView(model: XingGuangAppModel(catalogState: .loading)) }.previewDisplayName("Loading")
            NavigationView { VodHomeView(model: XingGuangAppModel(catalogState: .empty)) }.previewDisplayName("Empty")
        }
    }
}
