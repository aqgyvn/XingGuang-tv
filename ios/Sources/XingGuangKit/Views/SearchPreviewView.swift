import SwiftUI

struct SearchPreviewView: View {
    @ObservedObject var model: XingGuangAppModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var query = ""
    @State private var items: [Vod] = []
    @State private var loading = false
    @State private var loadingMore = false
    @State private var errorMessage = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var page = 1
    @State private var pageCount = 1
    @State private var activeKeyword = ""

    init(model: XingGuangAppModel, initialQuery: String = "") {
        self.model = model
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationView {
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
                        ForEach(items) { vod in
                            NavigationLink(destination: VodDetailPreviewView(vod: vod, model: model)) {
                                HStack(spacing: 12) {
                                    poster(vod)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(vod.vodName)
                                            .font(.headline)
                                            .foregroundColor(XingGuangTheme.text)
                                        Text([vod.typeName, vod.vodRemarks].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.subheadline)
                                            .foregroundColor(XingGuangTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onAppear {
                                if vod.id == items.last?.id {
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
        activeKeyword = keyword
        page = 1
        pageCount = 1
        model.recordSearch(keyword)
        searchTask = Task {
            do {
                if model.repositoryAvailable {
                    let result = try await model.searchPage(keyword: keyword)
                    items = result.list
                    pageCount = max(result.pageCount, 1)
                } else {
                    items = PreviewFixtures.vods.filter { $0.vodName.localizedCaseInsensitiveContains(keyword) }
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
        guard model.repositoryAvailable, !loading, !loadingMore, page < pageCount else { return }
        let keyword = activeKeyword
        let nextPage = page + 1
        loadingMore = true
        searchTask = Task {
            defer { loadingMore = false }
            do {
                let result = try await model.searchPage(keyword: keyword, page: nextPage)
                try Task.checkCancellation()
                guard activeKeyword == keyword else { return }
                var identifiers = Set(items.map(\.id))
                items.append(contentsOf: result.list.filter { identifiers.insert($0.id).inserted })
                page = nextPage
                pageCount = max(result.pageCount, nextPage)
            } catch is CancellationError {
            } catch {
            }
        }
    }
}
