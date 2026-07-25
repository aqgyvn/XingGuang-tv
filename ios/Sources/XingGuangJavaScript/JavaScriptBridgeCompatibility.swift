import CommonCrypto
import CoreFoundation
import Foundation
import Security

enum JavaScriptBridgeCrypto {
    static func aes(
        mode: String,
        encrypt: Bool,
        input: String,
        inputIsBase64: Bool,
        key: String,
        iv: String?,
        outputIsBase64: Bool
    ) -> String {
        guard let inputData = inputIsBase64 ? decodeBase64(input) : Data(input.utf8),
              let output = cryptAES(mode: mode, encrypt: encrypt, input: inputData, key: key, iv: iv) else {
            return ""
        }
        return outputIsBase64 ? output.base64EncodedString() : String(decoding: output, as: UTF8.self)
    }

    static func rsa(
        mode: String,
        publicKey: Bool,
        encrypt: Bool,
        input: String,
        inputIsBase64: Bool,
        key: String,
        outputIsBase64: Bool
    ) -> String {
        guard let inputData = inputIsBase64 ? decodeBase64(input) : Data(input.utf8),
              let secKey = makeRSAKey(key, publicKey: publicKey),
              let algorithm = rsaAlgorithm(mode),
              SecKeyIsAlgorithmSupported(secKey, encrypt ? .encrypt : .decrypt, algorithm) else {
            return ""
        }

        let preparedInput: Data
        if algorithm == .rsaEncryptionRaw, encrypt {
            let blockSize = SecKeyGetBlockSize(secKey)
            guard inputData.count <= blockSize else { return "" }
            preparedInput = Data(repeating: 0, count: blockSize - inputData.count) + inputData
        } else {
            preparedInput = inputData
        }

        var error: Unmanaged<CFError>?
        let result: Data?
        if encrypt {
            result = SecKeyCreateEncryptedData(secKey, algorithm, preparedInput as CFData, &error) as Data?
        } else {
            result = SecKeyCreateDecryptedData(secKey, algorithm, preparedInput as CFData, &error) as Data?
        }
        guard let result else { return "" }
        return outputIsBase64 ? result.base64EncodedString() : String(decoding: result, as: UTF8.self)
    }

    private static func cryptAES(mode: String, encrypt: Bool, input: Data, key: String, iv: String?) -> Data? {
        let normalizedMode = mode.uppercased()
        let usesECB: Bool
        if normalizedMode.hasPrefix("AES/ECB/") {
            usesECB = true
        } else if normalizedMode.hasPrefix("AES/CBC/") {
            usesECB = false
        } else {
            return nil
        }

        var options = CCOptions(0)
        if normalizedMode.hasSuffix("/PKCS5") || normalizedMode.hasSuffix("/PKCS7") {
            options |= CCOptions(kCCOptionPKCS7Padding)
        } else if !normalizedMode.hasSuffix("/NO") {
            return nil
        }
        if usesECB {
            options |= CCOptions(kCCOptionECBMode)
        }

        var keyData = Data(key.utf8)
        if keyData.count < kCCKeySizeAES128 {
            keyData.append(contentsOf: repeatElement(0, count: kCCKeySizeAES128 - keyData.count))
        }
        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(keyData.count) else {
            return nil
        }

        let ivData: Data?
        if usesECB {
            guard iv == nil else { return nil }
            ivData = nil
        } else if let iv {
            var data = Data(iv.utf8)
            if data.count < kCCBlockSizeAES128 {
                data.append(contentsOf: repeatElement(0, count: kCCBlockSizeAES128 - data.count))
            }
            guard data.count == kCCBlockSizeAES128 else { return nil }
            ivData = data
        } else {
            ivData = nil
        }

        var output = Data(count: input.count + kCCBlockSizeAES128)
        var outputLength = 0
        let status: CCCryptorStatus = output.withUnsafeMutableBytes { outputBytes in
            keyData.withUnsafeBytes { keyBytes in
                input.withUnsafeBytes { inputBytes in
                    let crypt: (UnsafeRawPointer?) -> CCCryptorStatus = { ivPointer in
                        CCCrypt(
                            encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes.baseAddress,
                            keyData.count,
                            ivPointer,
                            inputBytes.baseAddress,
                            input.count,
                            outputBytes.baseAddress,
                            output.count,
                            &outputLength
                        )
                    }
                    if let ivData {
                        return ivData.withUnsafeBytes { crypt($0.baseAddress) }
                    }
                    return crypt(nil)
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        output.count = outputLength
        return output
    }

    private static func rsaAlgorithm(_ mode: String) -> SecKeyAlgorithm? {
        mode == "RSA/None/NoPadding" ? .rsaEncryptionRaw : .rsaEncryptionPKCS1
    }

    private static func makeRSAKey(_ value: String, publicKey: Bool) -> SecKey? {
        var body = value
        for marker in [
            "-----BEGIN PUBLIC KEY-----", "-----END PUBLIC KEY-----",
            "-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----",
            "-----BEGIN RSA PUBLIC KEY-----", "-----END RSA PUBLIC KEY-----",
            "-----BEGIN RSA PRIVATE KEY-----", "-----END RSA PRIVATE KEY-----"
        ] {
            body = body.replacingOccurrences(of: marker, with: "")
        }
        body = body.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let encoded = decodeBase64(body) else { return nil }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: publicKey ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate
        ]
        let candidates = [encoded, unwrapRSAKey(encoded, publicKey: publicKey)].compactMap { $0 }
        for candidate in candidates {
            var error: Unmanaged<CFError>?
            if let key = SecKeyCreateWithData(candidate as CFData, attributes as CFDictionary, &error) {
                return key
            }
        }
        return nil
    }

    private static func unwrapRSAKey(_ data: Data, publicKey: Bool) -> Data? {
        let bytes = [UInt8](data)
        var rootOffset = 0
        guard let root = readDERItem(bytes, offset: &rootOffset), root.tag == 0x30 else { return nil }
        var offset = 0
        guard let first = readDERItem(root.value, offset: &offset),
              let second = readDERItem(root.value, offset: &offset) else { return nil }

        if publicKey, first.tag == 0x30, second.tag == 0x03, second.value.first == 0 {
            return Data(second.value.dropFirst())
        }
        if !publicKey, first.tag == 0x02, second.tag == 0x30,
           let third = readDERItem(root.value, offset: &offset), third.tag == 0x04 {
            return Data(third.value)
        }
        return nil
    }

    private static func readDERItem(_ bytes: [UInt8], offset: inout Int) -> (tag: UInt8, value: [UInt8])? {
        guard offset + 2 <= bytes.count else { return nil }
        let tag = bytes[offset]
        offset += 1
        var length = Int(bytes[offset])
        offset += 1
        if length & 0x80 != 0 {
            let byteCount = length & 0x7f
            guard byteCount > 0, byteCount <= 4, offset + byteCount <= bytes.count else { return nil }
            length = 0
            for _ in 0..<byteCount {
                length = (length << 8) | Int(bytes[offset])
                offset += 1
            }
        }
        guard length >= 0, offset + length <= bytes.count else { return nil }
        let value = Array(bytes[offset..<(offset + length)])
        offset += length
        return (tag, value)
    }

    private static func decodeBase64(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        while normalized.count % 4 != 0 {
            normalized.append("=")
        }
        return Data(base64Encoded: normalized, options: [.ignoreUnknownCharacters])
    }
}

enum JavaScriptTextDecoder {
    static func decode(_ data: Data, requestHeaders: [String: String]) -> String {
        let charsetName = requestHeaders.first {
            $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame
        }.flatMap { charset(from: $0.value) } ?? "utf-8"

        let encoding: String.Encoding
        switch charsetName.lowercased() {
        case "gbk", "gb2312", "gb18030", "gb-18030":
            let rawValue = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0632))
            encoding = String.Encoding(rawValue: rawValue)
        case "utf-16":
            encoding = .utf16
        case "utf-16le":
            encoding = .utf16LittleEndian
        case "utf-16be":
            encoding = .utf16BigEndian
        case "iso-8859-1", "latin1":
            encoding = .isoLatin1
        case "us-ascii", "ascii":
            encoding = .ascii
        default:
            encoding = .utf8
        }
        return String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
    }

    private static func charset(from contentType: String) -> String? {
        for component in contentType.split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if pair.count == 2, pair[0].caseInsensitiveCompare("charset") == .orderedSame {
                return pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }
}
