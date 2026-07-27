import SwiftUI

struct SearchPreviewView: View {
    @ObservedObject var model: XingGuangAppModel
    @Environment(\.presentationMode) private var presentationMode
    private let fixedSite: Site?
    @State private var query = ""
    @State private var items: [VodSearchItem] = []
    @State private var loading = false
    @State private var loadingMore = false
    @State private var errorMessage = ""
    @State private var partialFailureMessage = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var page = 1
    @State private var canLoadMore = false
    @State private var activeKeyword = ""
    @State private var searchAllSites: Bool

    init(model: XingGuangAppModel, initialQuery: String = "", initialSite: Site? = nil) {
        self.model = model
        self.fixedSite = initialSite
        _query = State(initialValue: initialQuery)
        _searchAllSites = State(initialValue: initialSite == nil)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if searchableSites.count > 1, fixedSite == nil {
                    Picker("搜索范围", selection: $searchAllSites) {
                        Text("全部站点").tag(true)
                        Text("当前站点").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Group {
                    if loading {
                        ProgressView("正在搜索")
                    } else if !errorMessage.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(errorMessage)
                        }
                        .foregroundColor(XingGuangTheme.secondaryText)
                    } else if items.isEmpty, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !model.searchHistory.isEmpty {
                        searchHistory
                    } else if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                            Text(query.isEmpty ? "输入影片名称" : "没有搜索结果")
                        }
                        .foregroundColor(XingGuangTheme.secondaryText)
                    } else {
                        List {
                            if !partialFailureMessage.isEmpty {
                                Label(partialFailureMessage, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(XingGuangTheme.secondaryText)
                            }
                            ForEach(items) { item in
                                NavigationLink(destination: VodDetailPreviewView(vod: item.vod, model: model, site: item.site)) {
                                    HStack(spacing: 12) {
                                        poster(item.vod)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.vod.vodName)
                                                .font(.headline)
                                                .foregroundColor(XingGuangTheme.text)
                                            Text([item.site.name, item.vod.typeName, item.vod.vodRemarks].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.subheadline)
                                                .foregroundColor(XingGuangTheme.secondaryText)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onAppear {
                                    if item.id == items.last?.id {
                                        loadNextPage()
                                    }
                                }
                            }
                            if loadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView("正在加载更多")
                                    Spacer()
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索影片")
            .onSubmit(of: .search) { performSearch() }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               activeKeyword.isEmpty {
                performSearch()
            }
        }
        .onDisappear { searchTask?.cancel() }
        .onChange(of: searchAllSites) { _ in
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { performSearch() }
        }
    }

    @ViewBuilder
    private func poster(_ vod: Vod) -> some View {
        if let url = URL(string: vod.vodPic), !vod.vodPic.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                posterPlaceholder
            }
            .frame(width: 54, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(XingGuangTheme.panelAccent)
            .frame(width: 54, height: 72)
            .overlay(Image(systemName: "play.rectangle.fill").foregroundColor(XingGuangTheme.primary))
    }

    private var searchHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("搜索记录")
                    .font(.headline)
                    .foregroundColor(XingGuangTheme.text)
                Spacer()
                Button("清空") { model.clearSearchHistory() }
                    .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.searchHistory, id: \.self) { keyword in
                        Button(keyword) {
                            query = keyword
                            performSearch()
                        }
                        .buttonStyle(.bordered)
                        .contextMenu {
                            Button("删除") { model.removeSearchHistory(keyword) }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(20)
    }

    private func performSearch() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        searchTask?.cancel()
        loading = true
        loadingMore = false
        errorMessage = ""
        partialFailureMessage = ""
        activeKeyword = keyword
        page = 1
        canLoadMore = false
        model.recordSearch(keyword)
        searchTask = Task {
            do {
                if model.repositoryAvailable {
                    if searchAllSites {
                        let result = try await model.searchAllSites(keyword: keyword)
                        items = result.items
                        canLoadMore = result.canLoadMore
                        partialFailureMessage = failureMessage(result.failedSiteNames)
                    } else {
                        let site = fixedSite ?? model.selectedSite
                        let result = try await model.searchPage(keyword: keyword, site: site)
                        items = result.list.map { VodSearchItem(site: site, vod: $0) }
                        canLoadMore = 1 < max(result.pageCount, 1)
                    }
                } else {
                    items = PreviewFixtures.vods
                        .filter { $0.vodName.localizedCaseInsensitiveContains(keyword) }
                        .map { VodSearchItem(site: fixedSite ?? model.selectedSite, vod: $0) }
                }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
                items = []
            }
            loading = false
        }
    }

    private func loadNextPage() {
        guard model.repositoryAvailable, !loading, !loadingMore, canLoadMore else { return }
        let keyword = activeKeyword
        let nextPage = page + 1
        let allSites = searchAllSites
        let site = fixedSite ?? model.selectedSite
        loadingMore = true
        searchTask = Task {
            defer { loadingMore = false }
            do {
                let result: [VodSearchItem]
                let hasMore: Bool
                let failedSites: [String]
                if allSites {
                    let aggregate = try await model.searchAllSites(keyword: keyword, page: nextPage)
                    result = aggregate.items
                    hasMore = aggregate.canLoadMore
                    failedSites = aggregate.failedSiteNames
                } else {
                    let single = try await model.searchPage(keyword: keyword, page: nextPage, site: site)
                    result = single.list.map { VodSearchItem(site: site, vod: $0) }
                    hasMore = nextPage < max(single.pageCount, 1)
                    failedSites = []
                }
                try Task.checkCancellation()
                guard activeKeyword == keyword, searchAllSites == allSites else { return }
                var identifiers = Set(items.map(\.id))
                items.append(contentsOf: result.filter { identifiers.insert($0.id).inserted })
                page = nextPage
                canLoadMore = hasMore
                partialFailureMessage = failureMessage(failedSites)
            } catch is CancellationError {
            } catch {
            }
        }
    }

    private var searchableSites: [Site] {
        model.configuration.sites.filter { $0.hide != 1 && $0.searchable != 0 }
    }

    private func failureMessage(_ names: [String]) -> String {
        names.isEmpty ? "" : "部分站点搜索失败：\(names.joined(separator: "、"))"
    }
}
