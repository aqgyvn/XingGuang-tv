import Foundation
import XCTest
@testable import XingGuangKit

final class HTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testSendsRequestCookieAndReadsResponseCookie() async throws {
        URLProtocolStub.handler = { request in
            URLProtocolStub.lastRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Set-Cookie": "session=abc; Path=/"]
            )!
            return (response, Data("ok".utf8))
        }

        let response = try await makeClient().send(
            HTTPRequest(url: URL(string: "https://example.com/catalog")!, cookies: ["token": "123"])
        )

        XCTAssertEqual(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Cookie"), "token=123")
        XCTAssertEqual(response.cookies["session"], "abc")
        XCTAssertEqual(response.data, Data("ok".utf8))
    }

    func testMapsHTTPFailureStatus() async {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await makeClient().send(HTTPRequest(url: URL(string: "https://example.com/forbidden")!))
            XCTFail("Expected HTTP status failure")
        } catch let error as HTTPClientError {
            XCTAssertEqual(error, .status(403))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTaskCancellationPropagatesAsCancellationError() async throws {
        URLProtocolStub.delay = 1
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = makeClient()
        let task = Task { try await client.send(HTTPRequest(url: URL(string: "https://example.com/slow")!)) }

        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSessionHTTPClient(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?
    static var delay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let reply = { [weak self] in
            guard let self else { return }
            let (response, data) = handler(self.request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if Self.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: reply)
        } else {
            reply()
        }
    }

    override func stopLoading() {}

    static func reset() {
        handler = nil
        lastRequest = nil
        delay = 0
    }
}
