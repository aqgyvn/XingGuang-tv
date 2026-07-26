import XCTest
@testable import XingGuangKit
@testable import XingGuangJavaScript

final class JavaScriptVodRepositoryTests: XCTestCase {
    func testBundledRootModuleAliasesLoadTheSameResource() throws {
        let host = QuickJSHostBox(
            site: Site(key: "bundle", api: "lib/http.js", type: 3),
            transport: ScriptTransport(sources: [:]),
            defaults: .standard
        )

        let libSource = try host.loadSource("lib/http.js")
        let assetSource = try host.loadSource("assets://js/lib/http.js")

        XCTAssertEqual(libSource, assetSource)
        XCTAssertTrue(libSource.contains("function http"))
    }

    func testTypeThreeScriptRunsSpiderProtocolAndMergesHome() async throws {
        let script = """
        export default {
          init: function(ext) { local.set('fixture', 'ready', '1'); },
          home: function(filter) { return JSON.stringify({"class":[{"type_id":"1","type_name":"电影"}],"filters":filter ? {"1":[]} : {}}); },
          homeVod: async function() { return JSON.stringify({"list":[{"vod_id":"7","vod_name":"脚本影片"}]}); },
          category: function(tid, page, filter, ext) { return JSON.stringify({"list":[{"vod_id":tid + page,"vod_name":"分类影片"}]}); },
          detail: function(id) { return JSON.stringify({"list":[{"vod_id":id,"vod_name":"详情影片","vod_play_from":"脚本线路","vod_play_url":"正片$https://cdn.example/video.m3u8"}]}); },
          search: function(key, quick, page) { return JSON.stringify({"list":[{"vod_id":"search","vod_name":key}]}); },
          play: function(flag, id, vipFlags) { return Promise.resolve(JSON.stringify({"url":id,"header":{"Referer":"https://example.com"}})); }
        };
        """
        let transport = ScriptTransport(sources: ["https://example.com/spider.js": Data(script.utf8)])
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "js", name: "脚本来源", api: "https://example.com/spider.js", type: 3)

        let home = try await repository.home(site: site, includeFilters: true)
        XCTAssertEqual(home.classes.first?.typeName, "电影")
        XCTAssertEqual(home.list.first?.vodName, "脚本影片")

        let category = try await repository.category(site: site, typeID: "1", page: 2, filters: [:])
        XCTAssertEqual(category.list.first?.vodID, "12")

        let detail = try await repository.detail(site: site, vodID: "7")
        XCTAssertEqual(detail.list.first?.playbackRoutes.first?.episodes.first?.url, "https://cdn.example/video.m3u8")

        let playback = try await repository.resolvePlayback(site: site, flag: "脚本线路", episodeURL: "https://cdn.example/video.m3u8")
        XCTAssertEqual(playback.url, "https://cdn.example/video.m3u8")
        XCTAssertEqual(playback.headers["Referer"], "https://example.com")
    }

    func testParsedPlaybackReturnsWebSniffingRequest() async throws {
        let script = """
        export default {
          init: function() {},
          play: function() { return JSON.stringify({"url":"https://example.com/player","parse":1}); }
        };
        """
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [
            "https://example.com/sniff.js": Data(script.utf8)
        ]))
        var site = Site(key: "sniff", name: "Sniff", api: "https://example.com/sniff.js", type: 3)
        site.click = "document.querySelector('video')?.play();"

        let playback = try await repository.resolvePlayback(site: site, flag: "线路", episodeURL: "https://example.com/player")

        XCTAssertTrue(playback.requiresSniffing)
        XCTAssertEqual(playback.url, "https://example.com/player")
        XCTAssertEqual(playback.sniffScript, site.click)
    }

    func testTypeThreeLocalAndMD5BridgesWork() async throws {
        let script = """
        export default {
          init: function() {},
          home: function() { local.set('fixture', 'value', md5X('abc')); return JSON.stringify({}); },
          homeVod: function() { return JSON.stringify({"list":[]}); },
          category: function() { return JSON.stringify({}); },
          detail: function() { return JSON.stringify({}); },
          search: function() { return JSON.stringify({}); },
          play: function() { return JSON.stringify({"url":"https://example.com/video.m3u8"}); }
        };
        """
        let defaults = UserDefaults(suiteName: "JavaScriptVodRepositoryTests.\(UUID().uuidString)")!
        let transport = ScriptTransport(sources: ["https://example.com/bridge.js": Data(script.utf8)])
        let repository = JavaScriptVodRepository(transport: transport, defaults: defaults)
        let site = Site(key: "bridge", name: "桥接来源", api: "https://example.com/bridge.js", type: 3)

        _ = try await repository.home(site: site, includeFilters: true)
        XCTAssertEqual(defaults.string(forKey: "cache_fixture_value"), "900150983cd24fb0d6963f7d28e17f72")
    }

    func testBundledHTTPModuleProvidesSyncReqAndPromiseHTTP() async throws {
        let script = """
        export default {
          init: function() {},
          home: async function() {
            const syncResult = req('https://api.example/sync');
            const asyncResult = await http('https://api.example/async');
            return JSON.stringify({"list":[{"vod_id":String(syncResult.code),"vod_name":syncResult.content + asyncResult.content}]});
          },
          homeVod: function() { return JSON.stringify({}); },
          category: function() { return JSON.stringify({}); },
          detail: function() { return JSON.stringify({}); },
          search: function() { return JSON.stringify({}); },
          play: function() { return JSON.stringify({"url":"https://example.com/video.m3u8"}); }
        };
        """
        let transport = ScriptTransport(sources: [
            "https://example.com/http.js": Data(script.utf8),
            "https://api.example/sync": Data("sync-".utf8),
            "https://api.example/async": Data("async".utf8)
        ])
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "http", name: "HTTP", api: "https://example.com/http.js", type: 3)

        let result = try await repository.home(site: site, includeFilters: true)

        XCTAssertEqual(result.list.first?.vodID, "200")
        XCTAssertEqual(result.list.first?.vodName, "sync-async")
    }

    func testRejectedPromiseIsReportedAsJavaScriptFailure() async throws {
        let script = """
        export default {
          init: function() {},
          home: function() { return Promise.reject(new Error('fixture rejected')); },
          homeVod: function() { return JSON.stringify({}); },
          category: function() { return JSON.stringify({}); },
          detail: function() { return JSON.stringify({}); },
          search: function() { return JSON.stringify({}); },
          play: function() { return JSON.stringify({"url":"https://example.com/video.m3u8"}); }
        };
        """
        let transport = ScriptTransport(sources: ["https://example.com/reject.js": Data(script.utf8)])
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "reject", name: "Reject", api: "https://example.com/reject.js", type: 3)

        do {
            _ = try await repository.home(site: site, includeFilters: true)
            XCTFail("Rejected promises must not be decoded as null")
        } catch let error as JavaScriptRuntimeError {
            XCTAssertTrue(error.localizedDescription.contains("fixture rejected"))
        }
    }

    func testRemainingSpiderProtocolMethodsAndProxyResponses() async throws {
        let script = """
        export default {
          init: function() {},
          isVideo: function(url) { return url.endsWith('.m3u8'); },
          sniffer: function() { return true; },
          action: function(value) { return 'handled:' + value; },
          proxy: function(params, headers) {
            if (Array.isArray(params)) {
              if (headers.Mode === 'raw') {
                return JSON.stringify({"code":200,"buffer":1,"content":"plain","headers":{"Content-Type":"text/plain"}});
              }
              return JSON.stringify({"code":206,"buffer":2,"content":"aGVsbG8=","headers":{"Content-Type":"text/plain","X-Mode":headers.Mode,"X-Segments":params.join('|')}});
            }
            return [201, "text/plain", [65, 66], {"X-Test":"ok"}, 0];
          }
        };
        """
        let transport = ScriptTransport(sources: ["https://example.com/protocol.js": Data(script.utf8)])
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "protocol", name: "Protocol", api: "https://example.com/protocol.js", type: 3)

        let video = try await repository.isVideo(site: site, url: "https://cdn.example/live.m3u8")
        let page = try await repository.isVideo(site: site, url: "https://cdn.example/page.html")
        let sniffer = try await repository.sniffer(site: site)
        let action = try await repository.action(site: site, value: "refresh")
        XCTAssertTrue(video)
        XCTAssertFalse(page)
        XCTAssertTrue(sniffer)
        XCTAssertEqual(action, "handled:refresh")

        let regular = try await repository.proxy(site: site, parameters: ["url": "https://api.example/proxy"])
        XCTAssertEqual(regular.statusCode, 201)
        XCTAssertEqual(regular.contentType, "text/plain")
        XCTAssertEqual(regular.data, Data("AB".utf8))
        XCTAssertEqual(regular.headers["X-Test"], "ok")

        let catVod = try await repository.proxy(site: site, parameters: [
            "from": "catvod",
            "url": "https://api.example/proxy/path/",
            "header": #"{"Mode":"catvod"}"#
        ])
        XCTAssertEqual(catVod.statusCode, 206)
        XCTAssertEqual(catVod.contentType, "text/plain")
        XCTAssertEqual(catVod.data, Data("hello".utf8))
        XCTAssertEqual(catVod.headers["X-Mode"], "catvod")
        XCTAssertEqual(catVod.headers["X-Segments"], "https:||api.example|proxy|path")

        let rawCatVod = try await repository.proxy(site: site, parameters: [
            "from": "catvod",
            "url": "https://api.example/proxy/raw/",
            "header": #"{"Mode":"raw"}"#
        ])
        XCTAssertEqual(rawCatVod.data, Data("plain".utf8))
    }

    func testLocalProxyServerRoutesOnlyRegisteredJavaScriptSite() async throws {
        let script = """
        export default {
          init: function() {},
          action: function() { return 'ready'; },
          proxy: function(params) { return [200, 'text/plain', 'proxied:' + params.value, {}, 0]; }
        };
        """
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [
            "https://example.com/local-proxy.js": Data(script.utf8)
        ]))
        let site = Site(key: "local-proxy", name: "Local Proxy", api: "https://example.com/local-proxy.js", type: 3)
        _ = try await repository.action(site: site, value: "")
        let server = LocalProxyServer(repository: repository)
        let endpoint = try await server.start()
        defer { server.stop() }
        for index in 0..<5 {
            let value = "ok-\(index)"
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "do", value: "js"),
                URLQueryItem(name: "siteKey", value: site.key),
                URLQueryItem(name: "value", value: value)
            ]

            let (data, response) = try await URLSession.shared.data(from: try XCTUnwrap(components.url))

            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertEqual(String(data: data, encoding: .utf8), "proxied:\(value)")
        }
    }

    func testQuickJSArgumentsRemainValidAcrossRepeatedAsyncCalls() async throws {
        let script = """
        export default {
          init: function() {},
          action: function(value) { return value; },
          proxy: function(params) { return [200, 'text/plain', params.value, {}, 0]; }
        };
        """
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [
            "https://example.com/repeated-arguments.js": Data(script.utf8)
        ]))
        let site = Site(key: "repeated-arguments", api: "https://example.com/repeated-arguments.js", type: 3)

        let first = try await repository.action(site: site, value: "first")
        XCTAssertEqual(first, "first")
        await Task.yield()
        let response = try await repository.proxy(site: site, parameters: ["value": "第二次调用"])

        XCTAssertEqual(String(data: response.data, encoding: .utf8), "第二次调用")
    }

    func testLiveContentUsesAndroidLiveProtocol() async throws {
        let script = """
        export default {
          init: function() {},
          live: function(url) {
            return JSON.stringify({"source":url,"groups":[{"name":"News","channel":[{"name":"One","url":"https://cdn.example/live.m3u8"}]}]});
          }
        };
        """
        let transport = ScriptTransport(sources: [
            "https://example.com/live.js": Data(script.utf8)
        ])
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "live", name: "Live", api: "https://example.com/live.js", type: 3)

        let raw = try await repository.liveContent(site: site, url: "https://source.example/live")
        let data = try XCTUnwrap(raw.data(using: .utf8))
        let live = try LivePlaylistParser.parse(data, into: Live(name: "fixture"))

        XCTAssertEqual(live.groups.first?.name, "News")
        XCTAssertEqual(live.groups.first?.channels.first?.urls.first, "https://cdn.example/live.m3u8")
    }

    func testInjectedProxyEndpointSupportsGetProxyAndJS2Proxy() async throws {
        let script = """
        export default {
          init: function() {},
          action: function() {
            return JSON.stringify({
              get: getProxy(true),
              js: js2Proxy(false, 3, 'fixture', 'https://media.example/video.m3u8', {'Referer':'https://example.com'})
            });
          }
        };
        """
        let transport = ScriptTransport(sources: ["https://example.com/proxy-bridge.js": Data(script.utf8)])
        let repository = JavaScriptVodRepository(
            transport: transport,
            proxyEndpoint: URL(string: "http://127.0.0.1:9978/proxy")!
        )
        let site = Site(key: "proxy-bridge", name: "Proxy", api: "https://example.com/proxy-bridge.js", type: 3)

        let raw = try await repository.action(site: site, value: "")
        let decoded = try JSONSerialization.jsonObject(with: Data(raw.utf8))
        let object = try XCTUnwrap(decoded as? [String: String])
        let getValue = try XCTUnwrap(object["get"])
        let jsValue = try XCTUnwrap(object["js"])
        let getURL = try XCTUnwrap(URLComponents(string: getValue))
        let jsURL = try XCTUnwrap(URLComponents(string: jsValue))
        let getQuery = Dictionary(uniqueKeysWithValues: (getURL.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        let jsQuery = Dictionary(uniqueKeysWithValues: (jsURL.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(getQuery["do"], "js")
        XCTAssertEqual(jsQuery["do"], "js")
        XCTAssertEqual(jsQuery["from"], "catvod")
        XCTAssertEqual(jsQuery["siteType"], "3")
        XCTAssertEqual(jsQuery["siteKey"], "fixture")
        XCTAssertEqual(jsQuery["url"], "https://media.example/video.m3u8")
        XCTAssertEqual(jsQuery["header"], #"{"Referer":"https://example.com"}"#)
    }

    func testMissingProxyEndpointReturnsExplicitUnsupportedError() async throws {
        let script = """
        export default {
          init: function() {},
          action: function() { return getProxy(true); }
        };
        """
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [
            "https://example.com/no-proxy.js": Data(script.utf8)
        ]))
        let site = Site(key: "no-proxy", name: "No Proxy", api: "https://example.com/no-proxy.js", type: 3)

        do {
            _ = try await repository.action(site: site, value: "")
            XCTFail("Missing proxy endpoint must not return an empty URL")
        } catch let error as JavaScriptRuntimeError {
            XCTAssertEqual(error, .unsupported("本地代理服务尚未配置；请注入 proxyEndpoint"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingOptionalSpiderMethodReturnsExplicitProtocolError() async throws {
        let script = """
        export default { init: function() {} };
        """
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [
            "https://example.com/minimal.js": Data(script.utf8)
        ]))
        let site = Site(key: "minimal", name: "Minimal", api: "https://example.com/minimal.js", type: 3)

        do {
            _ = try await repository.sniffer(site: site)
            XCTFail("Missing sniffer method must be reported")
        } catch let error as JavaScriptSpiderProtocolError {
            XCTAssertEqual(error, .unsupportedMethod("sniffer"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testJarAndPythonSourcesReturnExplicitCompatibilityErrors() async {
        let repository = JavaScriptVodRepository(transport: ScriptTransport(sources: [:]))
        let jar = Site(key: "jar", name: "JAR", api: "csp_Demo", type: 3)
        let python = Site(key: "python", name: "Python", api: "https://example.com/spider.py", type: 3)

        do {
            _ = try await repository.home(site: jar, includeFilters: true)
            XCTFail("JAR source should be rejected")
        } catch let error as VodRepositoryError {
            XCTAssertEqual(error.errorDescription, "iOS 暂不支持此来源依赖：Android JAR Spider（csp_）")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await repository.home(site: python, includeFilters: true)
            XCTFail("Python source should be rejected")
        } catch let error as VodRepositoryError {
            XCTAssertEqual(error.errorDescription, "iOS 暂不支持此来源依赖：Python Spider（Chaquopy）")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class ScriptTransport: JavaScriptHTTPTransport, @unchecked Sendable {
    private let sources: [String: Data]

    init(sources: [String: Data]) {
        self.sources = sources
    }

    func send(_ request: JavaScriptHTTPRequest) throws -> JavaScriptHTTPResponse {
        let data = sources[request.url.absoluteString] ?? Data()
        return JavaScriptHTTPResponse(statusCode: data.isEmpty ? 404 : 200, url: request.url, headers: [:], data: data)
    }
}
