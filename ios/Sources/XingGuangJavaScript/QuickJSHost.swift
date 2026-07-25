import CryptoKit
import Foundation
import CQuickJS
import XingGuangKit

final class QuickJSHostBox: @unchecked Sendable {
    let site: Site
    let transport: JavaScriptHTTPTransport
    let defaults: UserDefaults
    let proxyEndpoint: URL?
    private var sourceCache: [String: String] = [:]
    private var bridgeError: String?

    init(site: Site, transport: JavaScriptHTTPTransport, defaults: UserDefaults, proxyEndpoint: URL? = nil) {
        self.site = site
        self.transport = transport
        self.defaults = defaults
        self.proxyEndpoint = proxyEndpoint
    }

    func clearBridgeError() {
        bridgeError = nil
    }

    func consumeBridgeError() -> String? {
        defer { bridgeError = nil }
        return bridgeError
    }

    func rootModuleName() -> String {
        canonicalModuleName(site.api)
    }

    func isCatVodScript() -> Bool {
        guard let source = try? loadSource(site.api) else { return false }
        return source.contains("__jsEvalReturn")
    }

    func resolveModule(base: String, name: String) -> String? {
        if name.hasPrefix("lib/") {
            return "xg-lib://\(name)"
        }
        if name.hasPrefix("assets://js/lib/") {
            return "xg-lib://lib/\(name.dropFirst("assets://js/lib/".count))"
        }
        if let url = URL(string: name), url.scheme != nil {
            return url.absoluteString
        }
        if let url = URL(string: name, relativeTo: URL(string: base)) {
            let resolved = url.absoluteURL.absoluteString
            if resolved.contains("/lib/") {
                let fileName = URL(string: resolved)?.lastPathComponent ?? ""
                if resourceExists(fileName) {
                    return "xg-lib://lib/\(fileName)"
                }
            }
            return resolved
        }
        return nil
    }

    func loadSource(_ moduleName: String) throws -> String {
        let moduleName = canonicalModuleName(moduleName)
        if let cached = sourceCache[moduleName] { return cached }
        let data: Data
        if moduleName.hasPrefix("xg-lib://") {
            let relative = String(moduleName.dropFirst("xg-lib://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let fileName = relative.hasPrefix("lib/") ? String(relative.dropFirst(4)) : relative
            guard let url = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "JavaScript/lib") else {
                throw JavaScriptRuntimeError.invalidScript("找不到内置模块 \(relative)")
            }
            data = try Data(contentsOf: url)
        } else if let url = URL(string: moduleName), url.isFileURL {
            data = try Data(contentsOf: url)
        } else if let url = URL(string: moduleName), url.scheme == "http" || url.scheme == "https" {
            let response = try transport.send(JavaScriptHTTPRequest(
                url: url,
                headers: site.header,
                timeout: TimeInterval(site.timeout > 0 ? site.timeout : 15)
            ))
            guard (200..<400).contains(response.statusCode) else {
                throw JavaScriptRuntimeError.network("HTTP \(response.statusCode)")
            }
            data = response.data
        } else {
            throw JavaScriptRuntimeError.invalidScript("模块地址无效：\(moduleName)")
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw JavaScriptRuntimeError.invalidScript("模块不是 UTF-8 文本：\(moduleName)")
        }
        sourceCache[moduleName] = source
        return source
    }

    private func canonicalModuleName(_ value: String) -> String {
        if value.hasPrefix("lib/") {
            return "xg-lib://\(value)"
        }
        if value.hasPrefix("assets://js/lib/") {
            return "xg-lib://lib/\(value.dropFirst("assets://js/lib/".count))"
        }
        return value
    }

    func initialArgument() -> Any {
        let ext = site.ext?.asAny ?? ""
        if isCatVodScript() {
            var result: [String: Any] = [
                "stype": 3,
                "skey": site.key,
                "ext": ext
            ]
            return result
        }
        if let siteExtension = site.ext,
           case .string(let value) = siteExtension {
            return value
        }
        return ext
    }

    func bridge(name: String, payload: String) -> String? {
        let object = parseObject(payload)
        switch name {
        case "req", "http":
            return requestResponse(url: object["url"] as? String ?? "", options: object["options"] as? [String: Any] ?? [:])
        case "local.get":
            let key = localKey(rule: object["rule"] as? String ?? "", key: object["key"] as? String ?? "")
            return json(defaults.string(forKey: key) ?? "")
        case "local.set":
            let key = localKey(rule: object["rule"] as? String ?? "", key: object["key"] as? String ?? "")
            defaults.set(object["value"] as? String ?? "", forKey: key)
            return "null"
        case "local.delete":
            let key = localKey(rule: object["rule"] as? String ?? "", key: object["key"] as? String ?? "")
            defaults.removeObject(forKey: key)
            return "null"
        case "joinUrl":
            let parent = object["parent"] as? String ?? ""
            let child = object["child"] as? String ?? ""
            let value = URL(string: child, relativeTo: URL(string: parent))?.absoluteURL.absoluteString ?? child
            return json(value)
        case "md5X":
            let value = object["value"] as? String ?? ""
            let digest = Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
            return json(digest)
        case "s2t":
            return json(ChineseTextConverter.simplifiedToTraditional(object["value"] as? String ?? ""))
        case "t2s":
            return json(ChineseTextConverter.traditionalToSimplified(object["value"] as? String ?? ""))
        case "getProxy":
            guard let endpoint = proxyEndpoint,
                  let value = proxyURL(endpoint: endpoint, local: object["local"] as? Bool ?? false) else {
                bridgeError = "本地代理服务尚未配置；请注入 proxyEndpoint"
                return "null"
            }
            return json(value)
        case "js2Proxy":
            guard let endpoint = proxyEndpoint,
                  let value = jsProxyURL(endpoint: endpoint, object: object) else {
                bridgeError = "本地代理服务尚未配置；请注入 proxyEndpoint"
                return "null"
            }
            return json(value)
        case "aesX":
            return json(JavaScriptBridgeCrypto.aes(
                mode: object["mode"] as? String ?? "",
                encrypt: object["encrypt"] as? Bool ?? false,
                input: object["input"] as? String ?? "",
                inputIsBase64: object["inBase64"] as? Bool ?? false,
                key: object["key"] as? String ?? "",
                iv: object["iv"] as? String,
                outputIsBase64: object["outBase64"] as? Bool ?? false
            ))
        case "rsaX":
            return json(JavaScriptBridgeCrypto.rsa(
                mode: object["mode"] as? String ?? "",
                publicKey: object["pub"] as? Bool ?? false,
                encrypt: object["encrypt"] as? Bool ?? false,
                input: object["input"] as? String ?? "",
                inputIsBase64: object["inBase64"] as? Bool ?? false,
                key: object["key"] as? String ?? "",
                outputIsBase64: object["outBase64"] as? Bool ?? false
            ))
        case "console.log", "console.info", "console.warn", "console.error":
            return "null"
        default:
            return "null"
        }
    }

    private func requestResponse(url value: String, options: [String: Any]) -> String? {
        guard let url = URL(string: value) else {
            return json(["code": 0, "headers": [:], "content": ""])
        }
        let method = (options["method"] as? String ?? "get").uppercased()
        let timeout = ((options["timeout"] as? NSNumber)?.doubleValue ?? 10000) / 1000
        let redirect = ((options["redirect"] as? NSNumber)?.intValue ?? 1) == 1
        var headers = (options["headers"] as? [String: Any] ?? [:]).reduce(into: [String: String]()) { result, item in
            result[item.key] = String(describing: item.value)
        }
        let postType = options["postType"] as? String ?? "json"
        let body = requestBody(options: options, postType: postType, headers: &headers)
        do {
            let response = try transport.send(JavaScriptHTTPRequest(
                method: method == "HEADER" ? "HEAD" : method,
                url: url,
                headers: headers,
                body: body,
                timeout: max(timeout, 1),
                followsRedirects: redirect
            ))
            let buffer = (options["buffer"] as? NSNumber)?.intValue ?? 0
            let content: Any
            switch buffer {
            case 1, 3:
                content = Array(response.data)
            case 2:
                content = response.data.base64EncodedString()
            default:
                var decodingHeaders = response.headers
                for (key, value) in headers where !decodingHeaders.keys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                    decodingHeaders[key] = value
                }
                content = JavaScriptTextDecoder.decode(response.data, requestHeaders: decodingHeaders)
            }
            return json(["code": response.statusCode, "headers": response.headers, "content": content])
        } catch {
            return json(["code": 0, "headers": [:], "content": ""])
        }
    }

    private func requestBody(options: [String: Any], postType: String, headers: inout [String: String]) -> Data? {
        guard (options["method"] as? String ?? "get").lowercased() == "post" else { return nil }
        if let body = options["body"] as? String { return Data(body.utf8) }
        guard let value = options["data"] else { return nil }
        if postType == "json" {
            if !headers.keys.contains(where: { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
                headers["Content-Type"] = "application/json; charset=utf-8"
            }
            return try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
        }
        let dictionary = value as? [String: Any] ?? [:]
        if postType == "form" {
            if !headers.keys.contains(where: { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            }
            var components = URLComponents()
            components.queryItems = dictionary.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
            return components.percentEncodedQuery?.data(using: .utf8)
        }
        let boundary = "xg-\(UUID().uuidString)"
        if !headers.keys.contains(where: { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
            headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        }
        var data = Data()
        for (key, item) in dictionary {
            data.append(Data("--\(boundary)\r\n".utf8))
            data.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            data.append(Data("\(item)\r\n".utf8))
        }
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    private func localKey(rule: String, key: String) -> String {
        rule.isEmpty ? "cache_\(key)" : "cache_\(rule)_\(key)"
    }

    private func proxyURL(endpoint: URL, local: Bool) -> String? {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "do", value: "js"))
        if !local {
            queryItems.append(URLQueryItem(name: "local", value: "0"))
        }
        components?.queryItems = queryItems
        return components?.url?.absoluteString
    }

    private func jsProxyURL(endpoint: URL, object: [String: Any]) -> String? {
        let dynamic = object["dynamic"] as? Bool ?? false
        guard let base = proxyURL(endpoint: endpoint, local: !dynamic),
              var components = URLComponents(string: base) else { return nil }
        let headers = object["headers"] as? [String: Any] ?? [:]
        let headerData = try? JSONSerialization.data(withJSONObject: headers, options: [.fragmentsAllowed])
        let headerValue = headerData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let siteType = (object["siteType"] as? NSNumber)?.stringValue ?? "0"
        let siteKey = object["siteKey"] as? String ?? ""
        let url = object["url"] as? String ?? ""
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "from", value: "catvod"),
            URLQueryItem(name: "siteType", value: siteType),
            URLQueryItem(name: "siteKey", value: siteKey),
            URLQueryItem(name: "header", value: headerValue),
            URLQueryItem(name: "url", value: url)
        ])
        components.queryItems = queryItems
        return components.url?.absoluteString
    }

    private func parseObject(_ payload: String) -> [String: Any] {
        guard let data = payload.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        return value as? [String: Any] ?? [:]
    }

    private func json(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func resourceExists(_ fileName: String) -> Bool {
        Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "JavaScript/lib") != nil
    }
}

private extension JSONValue {
    var asAny: Any {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .object(let value): return value.mapValues { $0.asAny }
        case .array(let value): return value.map(\.asAny)
        case .null: return NSNull()
        }
    }
}

func quickJSBridgeCallback(
    _ name: UnsafePointer<CChar>?,
    _ payload: UnsafePointer<CChar>?,
    _ opaque: UnsafeMutableRawPointer?
) -> UnsafeMutablePointer<CChar>? {
    guard let opaque else { return nil }
    let host = Unmanaged<QuickJSHostBox>.fromOpaque(opaque).takeUnretainedValue()
    let nameValue = name.map { String(cString: $0) } ?? ""
    let payloadValue = payload.map { String(cString: $0) } ?? "{}"
    guard let result = host.bridge(name: nameValue, payload: payloadValue) else { return nil }
    return result.withCString { xg_quickjs_copy_string($0) }
}

func quickJSModuleResolverCallback(
    _ base: UnsafePointer<CChar>?,
    _ name: UnsafePointer<CChar>?,
    _ opaque: UnsafeMutableRawPointer?
) -> UnsafeMutablePointer<CChar>? {
    guard let opaque, let name else { return nil }
    let host = Unmanaged<QuickJSHostBox>.fromOpaque(opaque).takeUnretainedValue()
    let baseValue = base.map { String(cString: $0) } ?? ""
    let nameValue = String(cString: name)
    guard let result = host.resolveModule(base: baseValue, name: nameValue) else { return nil }
    return result.withCString { xg_quickjs_copy_string($0) }
}

func quickJSModuleLoaderCallback(
    _ name: UnsafePointer<CChar>?,
    _ opaque: UnsafeMutableRawPointer?
) -> UnsafeMutablePointer<CChar>? {
    guard let opaque, let name else { return nil }
    let host = Unmanaged<QuickJSHostBox>.fromOpaque(opaque).takeUnretainedValue()
    do {
        let result = try host.loadSource(String(cString: name))
        return result.withCString { xg_quickjs_copy_string($0) }
    } catch {
        return nil
    }
}
