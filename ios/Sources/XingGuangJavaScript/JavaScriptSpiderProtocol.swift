import Foundation

public enum JavaScriptSpiderProtocolError: Error, Equatable, LocalizedError {
    case unsupportedMethod(String)
    case invalidBoolean(method: String, value: String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedMethod(let method):
            return "JavaScript 来源未提供协议方法：\(method)"
        case .invalidBoolean(let method, let value):
            return "JavaScript 方法 \(method) 返回了无效布尔值：\(value)"
        case .invalidResponse(let method):
            return "JavaScript 方法 \(method) 返回的数据无效"
        }
    }
}

public struct JavaScriptProxyResponse: Equatable, Sendable {
    public let statusCode: Int
    public let contentType: String
    public let data: Data
    public let headers: [String: String]

    public init(
        statusCode: Int,
        contentType: String,
        data: Data,
        headers: [String: String] = [:]
    ) {
        self.statusCode = statusCode
        self.contentType = contentType
        self.data = data
        self.headers = headers
    }
}

enum JavaScriptSpiderProtocolCodec {
    static func string(_ raw: String, method: String) throws -> String {
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines) != "null" else {
            throw JavaScriptSpiderProtocolError.unsupportedMethod(method)
        }
        return raw
    }

    static func boolean(_ raw: String, method: String) throws -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "true", "1": return true
        case "false", "0": return false
        case "null", "": throw JavaScriptSpiderProtocolError.unsupportedMethod(method)
        default: throw JavaScriptSpiderProtocolError.invalidBoolean(method: method, value: raw)
        }
    }

    static func proxy(_ raw: String) throws -> JavaScriptProxyResponse {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
        }
        return try proxyObject(object)
    }

    private static func proxyObject(_ object: Any) throws -> JavaScriptProxyResponse {
        if let array = object as? [Any] {
            guard array.count >= 3 else { throw JavaScriptSpiderProtocolError.invalidResponse("proxy") }
            let statusCode = integer(array[0]) ?? 200
            let contentType = string(array[1]) ?? "application/octet-stream"
            let base64 = boolean(array.count > 4 ? array[4] : false)
            let headerValues = array.count > 3 ? headers(array[3]) : [:]
            let body = try bodyData(array[2], base64: base64)
            return JavaScriptProxyResponse(
                statusCode: statusCode,
                contentType: contentType,
                data: body,
                headers: headerValues
            )
        }

        guard let dictionary = object as? [String: Any] else {
            throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
        }
        if let nested = dictionary["response"] ?? dictionary["result"] {
            return try proxyObject(nested)
        }
        let statusCode = integer(dictionary["code"] ?? dictionary["status"] ?? dictionary["statusCode"]) ?? 200
        let headerValues = headers(dictionary["headers"] ?? dictionary["header"] ?? [String: Any]())
        let contentType = string(dictionary["contentType"] ?? dictionary["content-type"])
            ?? headerValues.first(where: { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame })?.value
            ?? "application/octet-stream"
        let bodyValue = dictionary["stream"] ?? dictionary["content"] ?? dictionary["body"] ?? ""
        let base64: Bool
        if let explicit = dictionary["base64"] {
            base64 = boolean(explicit)
        } else if let buffer = integer(dictionary["buffer"] as Any) {
            // CatVod's JSON response reserves buffer == 2 for Base64.
            base64 = buffer == 2
        } else {
            base64 = false
        }
        let body = try bodyData(bodyValue, base64: base64)
        return JavaScriptProxyResponse(
            statusCode: statusCode,
            contentType: contentType,
            data: body,
            headers: headerValues
        )
    }

    private static func bodyData(_ value: Any, base64: Bool) throws -> Data {
        if let bytes = value as? [Any] {
            let values = bytes.compactMap(integer)
            guard values.count == bytes.count, values.allSatisfy({ (0...255).contains($0) }) else {
                throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
            }
            return Data(values.map { UInt8($0) })
        }
        if let dictionary = value as? [String: Any] {
            if let nested = dictionary["data"] ?? dictionary["content"] ?? dictionary["stream"] {
                return try bodyData(nested, base64: base64)
            }
            throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
        }
        guard let text = string(value) else {
            if value is NSNull { return Data() }
            throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
        }
        var value = text
        if let range = value.range(of: "base64,", options: .caseInsensitive) {
            value = String(value[range.upperBound...])
        }
        if base64 {
            guard let decoded = Data(base64Encoded: value) else {
                throw JavaScriptSpiderProtocolError.invalidResponse("proxy")
            }
            return decoded
        }
        return Data(text.utf8)
    }

    private static func headers(_ value: Any) -> [String: String] {
        if let text = value as? String,
           let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            return headers(dictionary)
        }
        guard let dictionary = value as? [String: Any] else { return [:] }
        return dictionary.reduce(into: [:]) { result, item in
            if let text = string(item.value) { result[item.key] = text }
        }
    }

    private static func string(_ value: Any) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func integer(_ value: Any) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func boolean(_ value: Any) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }
}
