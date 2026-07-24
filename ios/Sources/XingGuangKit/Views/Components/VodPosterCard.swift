import SwiftUI

struct VodPosterCard: View {
    let vod: Vod
    let index: Int

    private var colors: [Color] {
        [
            Color(red: 0.72, green: 0.18, blue: 0.16),
            Color(red: 0.12, green: 0.55, blue: 0.72),
            Color(red: 0.22, green: 0.28, blue: 0.48),
            Color(red: 0.14, green: 0.55, blue: 0.39),
            Color(red: 0.64, green: 0.30, blue: 0.58),
            Color(red: 0.82, green: 0.52, blue: 0.14)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                poster

                Text(vod.vodRemarks.isEmpty ? vod.typeName : vod.vodRemarks)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(Color.black.opacity(0.76))
            }

            Text(vod.vodName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(XingGuangTheme.text)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        }
        .xingGuangPanel()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var poster: some View {
        if let url = URL(string: vod.vodPic), !vod.vodPic.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
        } else {
            placeholder
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
        }
    }

    private var placeholder: some View {
        colors[index % colors.count]
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
            )
    }
}
