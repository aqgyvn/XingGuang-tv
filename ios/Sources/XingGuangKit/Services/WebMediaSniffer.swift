import Foundation
import WebKit

public enum WebMediaSnifferError: Error, Equatable, LocalizedError {
    case invalidPageURL
    case timedOut
    case cancelled
    case navigation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPageURL: return "嗅探页面地址无效"
        case .timedOut: return "网页媒体嗅探超时"
        case .cancelled: return "网页媒体嗅探已取消"
        case .navigation(let message): return "网页加载失败：\(message)"
        }
    }
}

@MainActor
public protocol WebMediaSniffing: AnyObject {
    func resolve(_ request: PlaybackRequest, site: Site) async throws -> PlaybackRequest
}

@MainActor
public final class WebMediaSniffer: WebMediaSniffing {
    public typealias VideoValidator = @Sendable (Site, String) async throws -> Bool

    private let validator: VideoValidator?

    public init(validator: VideoValidator? = nil) {
        self.validator = validator
    }

    public func resolve(_ request: PlaybackRequest, site: Site) async throws -> PlaybackRequest {
        guard request.requiresSniffing else { return request }
        let session = WebMediaSniffSession(request: request, site: site, validator: validator)
        return try await withTaskCancellationHandler {
            try await session.run()
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
    }
}

@MainActor
private final class WebMediaSniffSession: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let request: PlaybackRequest
    private let site: Site
    private let validator: WebMediaSniffer.VideoValidator?
    private let contentController = WKUserContentController()
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<PlaybackRequest, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var testedURLs: Set<String> = []
    private var finished = false

    init(request: PlaybackRequest, site: Site, validator: WebMediaSniffer.VideoValidator?) {
        self.request = request
        self.site = site
        self.validator = validator
        super.init()
    }

    func run() async throws -> PlaybackRequest {
        guard let url = URL(string: request.url), url.scheme != nil else {
            throw WebMediaSnifferError.invalidPageURL
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start(url: url)
        }
    }

    func cancel() {
        finish(.failure(WebMediaSnifferError.cancelled))
    }

    private func start(url: URL) {
        contentController.add(self, name: "xingGuangMedia")
        contentController.addUserScript(WKUserScript(
            source: Self.observerScript + "\n" + request.sniffScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        if let userAgent = request.headers.first(where: { $0.key.caseInsensitiveCompare("User-Agent") == .orderedSame })?.value,
           !userAgent.isEmpty {
            webView.customUserAgent = userAgent
        }
        self.webView = webView

        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeout)
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        if !request.cookies.isEmpty {
            urlRequest.setValue(request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        }
        webView.load(urlRequest)

        let timeout = max(1, request.timeout)
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(.failure(WebMediaSnifferError.timedOut))
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let value = message.body as? String {
            consider(url: value, mimeType: nil)
        } else if let value = message.body as? [String: Any], let url = value["url"] as? String {
            consider(url: url, mimeType: value["type"] as? String)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if let url = navigationResponse.response.url?.absoluteString {
            consider(url: url, mimeType: navigationResponse.response.mimeType)
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(WebMediaSnifferError.navigation(error.localizedDescription)))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(WebMediaSnifferError.navigation(error.localizedDescription)))
    }

    private func consider(url value: String, mimeType: String?) {
        guard !finished,
              let url = URL(string: value, relativeTo: webView?.url)?.absoluteURL,
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "rtsp", "rtmp"].contains(scheme) else { return }
        let absolute = url.absoluteString
        guard testedURLs.insert(absolute).inserted else { return }
        guard testedURLs.count <= 128 else { return }

        if Self.looksLikeMedia(url: url, mimeType: mimeType) {
            complete(with: absolute)
            return
        }
        guard let validator else { return }
        let ignoredExtensions = ["css", "js", "json", "png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "woff", "woff2", "ttf", "vtt", "srt"]
        guard !ignoredExtensions.contains(url.pathExtension.lowercased()) else { return }
        Task {
            let accepted = (try? await validator(site, absolute)) == true
            guard accepted else { return }
            await MainActor.run { self.complete(with: absolute) }
        }
    }

    private func complete(with url: String) {
        Task { [weak self] in
            guard let self else { return }
            let cookies = await self.cookies(for: url)
            var resolved = self.request
            resolved.url = url
            resolved.cookies.merge(cookies) { _, new in new }
            resolved.requiresSniffing = false
            resolved.sniffScript = ""
            self.finish(.success(resolved))
        }
    }

    private func cookies(for value: String) async -> [String: String] {
        guard let url = URL(string: value), let store = webView?.configuration.websiteDataStore.httpCookieStore else { return [:] }
        return await withCheckedContinuation { continuation in
            store.getAllCookies { cookies in
                let values = cookies.reduce(into: [String: String]()) { result, cookie in
                    guard cookie.domain.isEmpty || url.host?.hasSuffix(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == true else { return }
                    result[cookie.name] = cookie.value
                }
                continuation.resume(returning: values)
            }
        }
    }

    private func finish(_ result: Result<PlaybackRequest, Error>) {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        contentController.removeScriptMessageHandler(forName: "xingGuangMedia")
        webView = nil
        continuation?.resume(with: result)
        continuation = nil
    }

    static func looksLikeMedia(url: URL, mimeType: String?) -> Bool {
        let type = mimeType?.lowercased() ?? ""
        if type.hasPrefix("video/") || type.hasPrefix("audio/") || type.contains("mpegurl") || type.contains("dash+xml") {
            return true
        }
        let extensionName = url.pathExtension.lowercased()
        return ["m3u8", "mpd", "mp4", "m4v", "mov", "mkv", "flv", "webm", "avi", "ts", "m2ts", "mp3", "aac", "m4a"].contains(extensionName)
            || ["rtsp", "rtmp"].contains(url.scheme?.lowercased() ?? "")
    }

    private static let observerScript = #"""
    (() => {
      const send = (url, type) => {
        if (!url || typeof url !== 'string') return;
        try { window.webkit.messageHandlers.xingGuangMedia.postMessage({url, type: type || ''}); } catch (_) {}
      };
      const originalFetch = window.fetch;
      if (originalFetch) window.fetch = function(input, init) {
        const url = typeof input === 'string' ? input : input && input.url;
        send(url, '');
        return originalFetch.apply(this, arguments).then(response => {
          send(response.url, response.headers && response.headers.get('content-type'));
          return response;
        });
      };
      const originalOpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(method, url) {
        this.__xingGuangURL = url;
        return originalOpen.apply(this, arguments);
      };
      const originalSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        send(this.__xingGuangURL, '');
        this.addEventListener('load', () => send(this.responseURL || this.__xingGuangURL, this.getResponseHeader('content-type')));
        return originalSend.apply(this, arguments);
      };
      const scan = root => {
        if (!root || !root.querySelectorAll) return;
        root.querySelectorAll('video,audio,source').forEach(node => send(node.currentSrc || node.src, node.type));
      };
      new MutationObserver(() => scan(document)).observe(document.documentElement || document, {subtree:true, childList:true, attributes:true, attributeFilter:['src']});
      if (window.PerformanceObserver) new PerformanceObserver(list => list.getEntries().forEach(entry => send(entry.name, ''))).observe({entryTypes:['resource']});
      document.addEventListener('play', event => send(event.target.currentSrc || event.target.src, ''), true);
      document.addEventListener('loadedmetadata', event => send(event.target.currentSrc || event.target.src, ''), true);
    })();
    """#
}
