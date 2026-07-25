import Foundation

public enum JavaScriptRuntimeError: Error, Equatable, LocalizedError {
    case invalidScript(String)
    case execution(String)
    case timeout
    case cancelled
    case network(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .invalidScript(let message): return "JavaScript 脚本无效：\(message)"
        case .execution(let message): return "JavaScript 执行失败：\(message)"
        case .timeout: return "JavaScript 执行超时"
        case .cancelled: return "JavaScript 执行已取消"
        case .network(let message): return "JavaScript 网络请求失败：\(message)"
        case .unsupported(let message): return "iOS 不支持此 JavaScript 能力：\(message)"
        }
    }
}
