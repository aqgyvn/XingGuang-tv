import Foundation

public enum HTTPMethod: String, Codable, Equatable {
    case get = "GET"
    case post = "POST"
}

public struct HTTPRequest: Equatable {
    public var method: HTTPMethod
    public var url: URL
    public var headers: [String: String]
    public var cookies: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        cookies: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 15
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.cookies = cookies
        self.body = body
        self.timeout = timeout
    }
}

public struct HTTPResponse {
    public let statusCode: Int
    public let url: URL?
    public let headers: [String: String]
    public let cookies: [String: String]
    public let data: Data

    public init(statusCode: Int, url: URL?, headers: [String: String], cookies: [String: String] = [:], data: Data) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.cookies = cookies
        self.data = data
    }
}

public enum HTTPClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case status(Int)
    case emptyResponse
    case timedOut
    case cancelled
    case transport(Int)
    case blocked(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "请求地址无效"
        case .invalidResponse: return "网络响应无效"
        case .status(let code): return "网络请求失败（HTTP \(code)）"
        case .emptyResponse: return "网络响应为空"
        case .timedOut: return "网络请求超时"
        case .cancelled: return "网络请求已取消"
        case .transport: return "网络连接失败"
        case .blocked(let host): return "请求已被广告规则拦截：\(host)"
        }
    }
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum HTTPUserAgent {
    public static let preferenceKey = "ios.globalUserAgent"

    public static func configured(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: preferenceKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public static func applyingDefault(to headers: [String: String], value: String) -> [String: String] {
        guard !headers.keys.contains(where: { $0.caseInsensitiveCompare("User-Agent") == .orderedSame }) else {
            return headers
        }
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return headers }
        var result = headers
        result["User-Agent"] = value
        return result
    }
}

public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
        private let policyStore: HTTPNetworkPolicyStore?

        init(policyStore: HTTPNetworkPolicyStore?) {
            self.policyStore = policyStore
        }

        func redirectedRequest(_ request: URLRequest) -> URLRequest? {
            guard let url = request.url, policyStore?.isBlocked(url) != true else { return nil }
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

    private let session: URLSession
    private let redirectDelegate: RedirectDelegate
    private let policyStore: HTTPNetworkPolicyStore?
    private let globalUserAgent: @Sendable () -> String

    public init(
        configuration: URLSessionConfiguration = .default,
        policyStore: HTTPNetworkPolicyStore? = nil,
        globalUserAgent: @escaping @Sendable () -> String = { HTTPUserAgent.configured() }
    ) {
        let sessionConfiguration = configuration
        sessionConfiguration.httpCookieStorage = HTTPCookieStorage.shared
        sessionConfiguration.httpShouldSetCookies = true
        sessionConfiguration.httpCookieAcceptPolicy = .always
        let redirectDelegate = RedirectDelegate(policyStore: policyStore)
        self.redirectDelegate = redirectDelegate
        self.session = URLSession(configuration: sessionConfiguration, delegate: redirectDelegate, delegateQueue: nil)
        self.policyStore = policyStore
        self.globalUserAgent = globalUserAgent
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var request = try policyStore?.prepare(request) ?? request
        request.headers = HTTPUserAgent.applyingDefault(to: request.headers, value: globalUserAgent())
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if !request.cookies.isEmpty {
            let cookie = request.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            urlRequest.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw HTTPClientError.timedOut
            case .cancelled: throw CancellationError()
            default: throw HTTPClientError.transport(error.code.rawValue)
            }
        }
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        if let finalURL = httpResponse.url {
            try policyStore?.validate(finalURL)
        }
        if let redirectURL = HTTPRedirectPolicy.targetURL(from: httpResponse, originalURL: request.url) {
            try policyStore?.validate(redirectURL)
        }
        let responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        let headers = responseHeaders.reduce(into: [String: String]()) { result, item in
            result[item.key.lowercased()] = item.value
        }
        guard (200..<400).contains(httpResponse.statusCode) else {
            throw HTTPClientError.status(httpResponse.statusCode)
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: responseHeaders, for: httpResponse.url ?? request.url)
            .reduce(into: [String: String]()) { result, cookie in result[cookie.name] = cookie.value }
        return HTTPResponse(statusCode: httpResponse.statusCode, url: httpResponse.url, headers: headers, cookies: cookies, data: data)
    }
}

public extension URLRequest {
    func withCookieHeader(_ cookies: [String: String]) -> URLRequest {
        guard !cookies.isEmpty else { return self }
        var request = self
        request.setValue(cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        return request
    }
}
