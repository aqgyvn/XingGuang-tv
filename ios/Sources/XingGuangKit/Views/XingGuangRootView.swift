import SwiftUI

@MainActor
public struct XingGuangRootView: View {
    @StateObject private var model: XingGuangAppModel

    public init(model: XingGuangAppModel = XingGuangAppModel()) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        TabView {
            NavigationView {
                VodHomeView(model: model)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("点播", systemImage: "film")
            }

            NavigationView {
                LiveHomeView(model: model)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("直播", systemImage: "play.tv")
            }

            NavigationView {
                SettingsView(model: model)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .accentColor(XingGuangTheme.primary)
        .accessibilityIdentifier("xingguang.root.tabs")
        .task {
            model.bootstrap()
        }
    }
}

struct XingGuangRootView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            XingGuangRootView()
                .previewDisplayName("iPhone")
                .previewDevice("iPhone 13")
            XingGuangRootView()
                .previewDisplayName("iPad")
                .previewDevice("iPad Pro (11-inch) (4th generation)")
        }
    }
}
