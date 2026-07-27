import Foundation
import XingGuangKit

public struct JavaScriptHTTPRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval
    public var followsRedirects: Bool

    public init(
        method: String = "GET",
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 10,
        followsRedirects: Bool = true
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.followsRedirects = followsRedirects
    }
}

public struct JavaScriptHTTPResponse: Sendable {
    public var statusCode: Int
    public var url: URL?
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, url: URL?, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.data = data
    }
}

public protocol JavaScriptHTTPTransport: Sendable {
    func send(_ request: JavaScriptHTTPRequest) throws -> JavaScriptHTTPResponse
}

public final class URLSessionJavaScriptHTTPTransport: NSObject, JavaScriptHTTPTransport, @unchecked Sendable {
    final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
        let followsRedirects: Bool
        private let policyStore: HTTPNetworkPolicyStore?

        init(followsRedirects: Bool, policyStore: HTTPNetworkPolicyStore?) {
            self.followsRedirects = followsRedirects
            self.policyStore = policyStore
        }

        func redirectedRequest(_ request: URLRequest) -> URLRequest? {
            guard followsRedirects,
                  let url = request.url,
                  policyStore?.isBlocked(url) != true else { return nil }
            return request
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(redirectedRequest(request))
        }
    }

    private let policyStore: HTTPNetworkPolicyStore?
    private let globalUserAgent: @Sendable () -> String

    public init(
        policyStore: HTTPNetworkPolicyStore? = nil,
        globalUserAgent: @escaping @Sendable () -> String = { HTTPUserAgent.configured() }
    ) {
        self.policyStore = policyStore
        self.globalUserAgent = globalUserAgent
        super.init()
    }

    public func send(_ request: JavaScriptHTTPRequest) throws -> JavaScriptHTTPResponse {
        let policyRequest = try policyStore?.prepare(HTTPRequest(
            method: request.method.uppercased() == "POST" ? .post : .get,
            url: request.url,
            headers: request.headers,
            body: request.body,
            timeout: request.timeout
        ))
        let requestHeaders = HTTPUserAgent.applyingDefault(
            to: policyRequest?.headers ?? request.headers,
            value: globalUserAgent()
        )
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.uppercased()
        urlRequest.httpBody = request.body
        for (key, value) in requestHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = RedirectDelegate(followsRedirects: request.followsRedirects, policyStore: policyStore)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let semaphore = DispatchSemaphore(value: 0)
        var receivedData = Data()
        var receivedResponse: URLResponse?
        var receivedError: Error?

        let task = session.dataTask(with: urlRequest) { data, response, error in
            receivedData = data ?? Data()
            receivedResponse = response
            receivedError = error
            semaphore.signal()
        }
        task.resume()

        let waitResult = semaphore.wait(timeout: .now() + max(request.timeout, 1) + 1)
        if waitResult == .timedOut {
            task.cancel()
            session.invalidateAndCancel()
            throw JavaScriptRuntimeError.timeout
        }
        session.invalidateAndCancel()
        if let receivedError {
            throw JavaScriptRuntimeError.network(receivedError.localizedDescription)
        }
        guard let response = receivedResponse as? HTTPURLResponse else {
            throw JavaScriptRuntimeError.network("网络响应无效")
        }
        if let finalURL = response.url {
            try policyStore?.validate(finalURL)
        }
        if request.followsRedirects,
           let redirectURL = HTTPRedirectPolicy.targetURL(from: response, originalURL: request.url) {
            try policyStore?.validate(redirectURL)
        }

        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        return JavaScriptHTTPResponse(
            statusCode: response.statusCode,
            url: response.url,
            headers: headers,
            data: receivedData
        )
    }
}
