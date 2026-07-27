import Foundation
import XCTest
@testable import XingGuangJavaScript
@testable import XingGuangKit

final class JavaScriptHTTPTests: XCTestCase {
    func testRedirectDelegateHonorsFollowFlagAndAdPolicy() {
        let policy = HTTPNetworkPolicyStore()
        policy.apply(VodConfigDocument(ads: ["ads.example"]))
        let allowed = URLRequest(url: URL(string: "https://video.example/landing")!)
        let blocked = URLRequest(url: URL(string: "https://video.ads.example/landing")!)

        let following = URLSessionJavaScriptHTTPTransport.RedirectDelegate(
            followsRedirects: true,
            policyStore: policy
        )
        XCTAssertNotNil(following.redirectedRequest(allowed))
        XCTAssertNil(following.redirectedRequest(blocked))

        let disabled = URLSessionJavaScriptHTTPTransport.RedirectDelegate(
            followsRedirects: false,
            policyStore: policy
        )
        XCTAssertNil(disabled.redirectedRequest(allowed))
    }
}
