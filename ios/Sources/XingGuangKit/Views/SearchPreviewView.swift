import SwiftUI

struct SearchPreviewView: View {
    @ObservedObject var model: XingGuangAppModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var query = ""
    @State private var items: [Vod] = []
    @State private var loading = false
    @State private var errorMessage = ""
    @State private var searchTask: Task<Void, Never>?

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
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                        Text(query.isEmpty ? "输入影片名称" : "没有搜索结果")
                    }
                    .foregroundColor(XingGuangTheme.secondaryText)
                } else {
                    List(items) { vod in
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

    private func performSearch() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        searchTask?.cancel()
        loading = true
        errorMessage = ""
        searchTask = Task {
            do {
                if model.repositoryAvailable {
                    items = try await model.search(keyword: keyword)
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
}
