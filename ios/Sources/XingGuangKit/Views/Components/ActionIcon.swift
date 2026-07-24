import SwiftUI

struct ActionIcon: View {
    let systemName: String
    let label: String
    var highlighted = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 21, weight: .semibold))
            .foregroundColor(highlighted ? .white : XingGuangTheme.text)
            .frame(width: 44, height: 44)
            .background(highlighted ? XingGuangTheme.primary : Color.clear)
            .clipShape(Circle())
            .contentShape(Circle())
            .accessibilityLabel(label)
    }
}
