import SwiftUI
import XingGuangKit

@main
struct XingGuangApp: App {
    @StateObject private var model: XingGuangAppModel

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            _model = StateObject(wrappedValue: XingGuangAppModel())
            return
        }
        let store = try? AppDatabase.live()
        let factory = ClosurePlayerEngineFactory(
            avPlayer: { AVPlayerEngine() },
            vlc: { VLCPlayerEngineAdapter() }
        )
        _model = StateObject(wrappedValue: XingGuangAppModel(
            repository: ApiVodRepository(),
            persistence: store,
            playerFactory: factory,
            usePreviewData: false
        ))
    }

    var body: some Scene {
        WindowGroup {
            XingGuangRootView(model: model)
        }
    }
}
