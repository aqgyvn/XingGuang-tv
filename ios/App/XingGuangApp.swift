import SwiftUI
import XingGuangKit
import XingGuangJavaScript

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
        let javascript = JavaScriptVodRepository()
        let repository = RoutingVodRepository(
            api: ApiVodRepository(),
            javascript: javascript
        )
        let liveRepository = DefaultLiveRepository(dynamicContentLoader: { live in
            var site = Site(key: live.name, name: live.name, api: live.api, type: 3)
            site.ext = live.ext
            site.jar = live.jar
            site.header = live.header
            site.timeout = live.timeout
            return try await javascript.liveContent(site: site, url: live.url)
        })
        _model = StateObject(wrappedValue: XingGuangAppModel(
            repository: repository,
            liveRepository: liveRepository,
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
