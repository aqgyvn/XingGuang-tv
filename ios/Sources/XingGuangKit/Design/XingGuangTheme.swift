import SwiftUI

public enum XingGuangTheme {
    public static let background = Color(red: 0.965, green: 0.976, blue: 0.992)
    public static let panel = Color.white
    public static let panelAccent = Color(red: 0.895, green: 0.935, blue: 0.990)
    public static let primary = Color(red: 0.180, green: 0.435, blue: 0.890)
    public static let text = Color(red: 0.075, green: 0.115, blue: 0.205)
    public static let secondaryText = Color(red: 0.390, green: 0.445, blue: 0.555)
    public static let border = Color(red: 0.820, green: 0.865, blue: 0.925)
    public static let playerBackground = Color.black
}

extension View {
    func xingGuangPanel() -> some View {
        self
            .background(XingGuangTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(XingGuangTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
