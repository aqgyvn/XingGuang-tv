import XCTest
@testable import XingGuangKit
@testable import XingGuangJavaScript

final class JavaScriptCryptoBridgeTests: XCTestCase {
    func testAESPKCS5FixtureMatchesAndroidAndDecrypts() async throws {
        let script = """
        export default {
          init: function() {},
          action: function() {
            const encrypted = aesX('AES/CBC/PKCS5', true, '\\u661f\\u5149-AES', false, '0123456789abcdef', 'abcdef9876543210', true);
            const decrypted = aesX('AES/CBC/PKCS5', false, encrypted, true, '0123456789abcdef', 'abcdef9876543210', false);
            return JSON.stringify({encrypted: encrypted, decrypted: decrypted});
          }
        };
        """
        let repository = JavaScriptVodRepository(transport: CompatibilityTransport(
            responses: ["https://example.com/aes.js": Data(script.utf8)]
        ))
        let site = Site(key: "aes", name: "AES", api: "https://example.com/aes.js", type: 3)

        let raw = try await repository.action(site: site, value: "")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: String])
        XCTAssertEqual(object["encrypted"], "prl/TvzJAMKu76w8wCF1Mw==")
        XCTAssertEqual(object["decrypted"], "星光-AES")
    }

    func testRSAPKCS1FixturesUseX509AndPKCS8Keys() async throws {
        let publicKey = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCKMBx21dIZA67lOxW5rrHx0rEIDEQ5dmEEv4ybC5dT4TTw4gMuJH/S4F+5sfcqLsVIhMAvbnW7T9+vaMM7V6RBCxaSRvxSrIlQkaV6mcuEtDCcaPbLmHzwQWv6NRHjGTRg3zCEzSj04QJ/keV8UGkcdvbc5axB1/5aKIoG7HAtAwIDAQAB"
        let privateKey = "MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAIowHHbV0hkDruU7FbmusfHSsQgMRDl2YQS/jJsLl1PhNPDiAy4kf9LgX7mx9youxUiEwC9udbtP369owztXpEELFpJG/FKsiVCRpXqZy4S0MJxo9suYfPBBa/o1EeMZNGDfMITNKPThAn+R5XxQaRx29tzlrEHX/looigbscC0DAgMBAAECgYAKSp38Ewg+zlbqrIqoKwSxTAMyOb5PrJYkz+KNXit1gZq7QTctFbvNUozehrdagA7iS+dc657qBdSqECUmGMIF7T0FDKYMNAJXkxX2ZFrLuAOzbDF8giogPvWogUyzL7UTUbA18l3wHhxK5gGW0dG3ULUI04wo9riRFe9GUxcVzQJBANEFSudfaS0qb86nqkQ8SWIFmmg/H5xT1FMWjU0n9pE5PzbIPA04lsHOTZxHlRnpJnnj9ghwxZf2r5TL/OMuFQ8CQQCpPzf88Mdd919EKk9i99bqT/ZSG3TKd0FyHpc6AT0d54x53XfPlXa6J6IFU4VI4biDK5hlBH2p7M32njbzAbDNAkAJGjfm14rXArAXyclqa02uzRuqSoVv416tt5+zqnfcXyfXlOS4lqxKCFfs5Fkj5bldOYYvW+ne8kk3K6L5qboVAkEAp9RE1NJ/ILMZCSNbraxOtfOtMyZ+3fb8MwoatC5eSLVAG+h90p9IKLj8dYOo++i5a3ljmWimpEZqx0+E9dyLUQJAJnHzfjFqREO+uzxDadxfvMzG4NiTeHrL9KhSF2Q9LXDppj2k97OYmaJUKuqQVzm0t6OUU0XUirMwGwTFuqcUsw=="
        let fixedCiphertext = "V5yTBn/2NGSFwr/DTN5ZEb8Zq25VN2O+xt/f6tVj+e9X4zxQJL7a6m7UPM4Ie9ib0BqWXyG4r200OxNObJrRcy3GFeCbplLLe3z17nTuPvZDn4Svqn7zLlC75GZtLMs7z4M3IadA6w5bDqr1C3fwA7c04mWT/JTOE8xciAXImOw="
        let script = """
        export default {
          init: function() {},
          action: function() {
            const fixed = rsaX('RSA/PKCS1', false, false, '\(fixedCiphertext)', true, '\(privateKey)', false);
            const encrypted = rsaX('RSA/PKCS1', true, true, '\\u661f\\u5149-RSA', false, '\(publicKey)', true);
            const roundTrip = rsaX('RSA/PKCS1', false, false, encrypted, true, '\(privateKey)', false);
            return JSON.stringify({fixed: fixed, encrypted: encrypted, roundTrip: roundTrip});
          }
        };
        """
        let repository = JavaScriptVodRepository(transport: CompatibilityTransport(
            responses: ["https://example.com/rsa.js": Data(script.utf8)]
        ))
        let site = Site(key: "rsa", name: "RSA", api: "https://example.com/rsa.js", type: 3)

        let raw = try await repository.action(site: site, value: "")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: String])
        XCTAssertEqual(object["fixed"], "星光-RSA")
        XCTAssertFalse(try XCTUnwrap(object["encrypted"]).isEmpty)
        XCTAssertEqual(object["roundTrip"], "星光-RSA")
    }

    func testSimplifiedTraditionalAndGBKRequestCharsetFixtures() async throws {
        let script = """
        export default {
          init: function() {},
          action: function() {
            const response = req('https://api.example/gbk', {headers: {'Content-Type': 'text/plain; charset=GBK'}});
            return JSON.stringify({traditional: s2t('\\u4e07\\u56fd\\u4e91\\u9f99'), simplified: t2s('\\u842c\\u570b\\u96f2\\u9f8d'), content: response.content});
          }
        };
        """
        let transport = CompatibilityTransport(
            responses: [
                "https://example.com/text.js": Data(script.utf8),
                "https://api.example/gbk": Data([0xD0, 0xC7, 0xB9, 0xE2])
            ],
            responseHeaders: ["https://api.example/gbk": ["Content-Type": "text/plain; charset=GBK"]]
        )
        let repository = JavaScriptVodRepository(transport: transport)
        let site = Site(key: "encoding", name: "编码", api: "https://example.com/text.js", type: 3)

        let raw = try await repository.action(site: site, value: "")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: String])
        XCTAssertEqual(object["traditional"], "萬國雲龍")
        XCTAssertEqual(object["simplified"], "万国云龙")
        XCTAssertEqual(object["content"], "星光")
    }
}

private final class CompatibilityTransport: JavaScriptHTTPTransport, @unchecked Sendable {
    private let responses: [String: Data]
    private let responseHeaders: [String: [String: String]]

    init(responses: [String: Data], responseHeaders: [String: [String: String]] = [:]) {
        self.responses = responses
        self.responseHeaders = responseHeaders
    }

    func send(_ request: JavaScriptHTTPRequest) throws -> JavaScriptHTTPResponse {
        let data = responses[request.url.absoluteString] ?? Data()
        return JavaScriptHTTPResponse(
            statusCode: data.isEmpty ? 404 : 200,
            url: request.url,
            headers: responseHeaders[request.url.absoluteString] ?? [:],
            data: data
        )
    }
}
