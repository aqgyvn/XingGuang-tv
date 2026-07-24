import SwiftUI

struct CollectionPreviewView: View {
    let title: String
    let items: [Vod]
    let model: XingGuangAppModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 136, maximum: 190), spacing: 16)], spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, vod in
                    NavigationLink(destination: VodDetailPreviewView(vod: vod, model: model)) {
                        VodPosterCard(vod: vod, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(XingGuangTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
