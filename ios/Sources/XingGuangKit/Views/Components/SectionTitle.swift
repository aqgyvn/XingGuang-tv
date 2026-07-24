import SwiftUI

struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(XingGuangTheme.primary)
                .frame(width: 4, height: 24)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(XingGuangTheme.text)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundColor(XingGuangTheme.secondaryText)
            }
        }
    }
}
