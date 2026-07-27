import SwiftUI
import XingGuangKit
import XingGuangJavaScript

@main
struct XingGuangApp: App {
    @StateObject private var model: XingGuangAppModel
    private let proxyServer: LocalProxyServer?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            _model = StateObject(wrappedValue: XingGuangAppModel())
            proxyServer = nil
            return
        }
        let store = try? AppDatabase.live()
        let factory = ClosurePlayerEngineFactory(
            mpv: { MPVPlayerEngineAdapter() },
            mdk: { MDKPlayerEngineAdapter() },
            avPlayer: { AVPlayerEngine() }
        )
        let networkPolicy = HTTPNetworkPolicyStore()
        let httpClient = URLSessionHTTPClient(policyStore: networkPolicy)
        let parseResolver = PlaybackParseResolver(client: httpClient)
        let javascript = JavaScriptVodRepository(
            transport: URLSessionJavaScriptHTTPTransport(policyStore: networkPolicy),
            parseResolver: parseResolver
        )
        let proxyServer = LocalProxyServer(repository: javascript)
        self.proxyServer = proxyServer
        let repository = RoutingVodRepository(
            api: ApiVodRepository(client: httpClient, parseResolver: parseResolver),
            javascript: javascript
        )
        let liveRepository = DefaultLiveRepository(client: httpClient, dynamicContentLoader: { live in
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
            timedTextLoader: TimedTextLoader(client: httpClient),
            webMediaSniffer: WebMediaSniffer(validator: { site, url in
                try await javascript.isVideo(site: site, url: url)
            }, policyStore: networkPolicy),
            networkPolicyStore: networkPolicy,
            usePreviewData: false
        ))
    }

    var body: some Scene {
        WindowGroup {
            XingGuangRootView(model: model, prepare: {
                _ = try? await proxyServer?.start()
            })
        }
    }
}
