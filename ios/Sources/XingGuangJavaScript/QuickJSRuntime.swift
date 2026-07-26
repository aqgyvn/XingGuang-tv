import Foundation
import CQuickJS
import XingGuangKit

private final class QuickJSHandleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: OpaquePointer?

    init(_ handle: OpaquePointer?) {
        self.handle = handle
    }

    func current() -> OpaquePointer? {
        lock.lock()
        defer { lock.unlock() }
        return handle
    }

    func interrupt() {
        lock.lock()
        defer { lock.unlock() }
        if let handle { xg_quickjs_interrupt(handle) }
    }

    func dispose() {
        lock.lock()
        let handle = self.handle
        self.handle = nil
        lock.unlock()
        if let handle { xg_quickjs_destroy(handle) }
    }
}

public actor QuickJSRuntime {
    private let host: QuickJSHostBox
    private nonisolated let handleBox: QuickJSHandleBox
    private let initialArgumentJSON: String
    private var initialized = false
    private let timeout: TimeInterval

    public init(
        site: Site,
        transport: JavaScriptHTTPTransport,
        defaults: UserDefaults = .standard,
        proxyEndpoint: JavaScriptProxyEndpoint = JavaScriptProxyEndpoint()
    ) {
        let host = QuickJSHostBox(
            site: site,
            transport: transport,
            defaults: defaults,
            proxyEndpoint: proxyEndpoint
        )
        self.host = host
        self.timeout = TimeInterval(site.timeout > 0 ? site.timeout : 15)
        let pointer = Unmanaged.passUnretained(host).toOpaque()
        self.handleBox = QuickJSHandleBox(xg_quickjs_create(
            quickJSBridgeCallback,
            quickJSModuleResolverCallback,
            quickJSModuleLoaderCallback,
            pointer
        ))
        if let data = try? JSONSerialization.data(
            withJSONObject: [host.initialArgument()],
            options: [.fragmentsAllowed]
        ), let value = String(data: data, encoding: .utf8) {
            self.initialArgumentJSON = value
        } else {
            self.initialArgumentJSON = "[\"\"]"
        }
    }

    deinit {
        handleBox.dispose()
    }

    public nonisolated func initialize() async throws {
        try await withTaskCancellationHandler(operation: {
            try await self.initializeIsolated()
        }, onCancel: {
            self.handleBox.interrupt()
        })
    }

    public nonisolated func call(_ method: String, arguments: [Any]) async throws -> String {
        guard JSONSerialization.isValidJSONObject(arguments) else {
            throw JavaScriptRuntimeError.execution("JavaScript 参数无法编码")
        }
        let data = try JSONSerialization.data(withJSONObject: arguments, options: [.fragmentsAllowed])
        guard let json = String(data: data, encoding: .utf8) else {
            throw JavaScriptRuntimeError.execution("JavaScript 参数不是 UTF-8")
        }
        return try await withTaskCancellationHandler(operation: {
            try await self.callJSON(method, argumentsJSON: json)
        }, onCancel: {
            self.handleBox.interrupt()
        })
    }

    public nonisolated func interrupt() {
        handleBox.interrupt()
    }

    public func dispose() {
        handleBox.dispose()
    }

    private func initializeIsolated() throws {
        guard let handle = handleBox.current() else {
            throw JavaScriptRuntimeError.execution("QuickJS context 创建失败")
        }
        guard !initialized else { return }
        host.clearBridgeError()
        setDeadline(handle)
        guard xg_quickjs_load_spider(handle, host.rootModuleName()) == 0 else {
            throw scriptError(lastError(handle))
        }
        if let bridgeError = host.consumeBridgeError() {
            throw JavaScriptRuntimeError.unsupported(bridgeError)
        }
        _ = try callJSON("init", argumentsJSON: initialArgumentJSON)
        initialized = true
    }

    private func callJSON(_ method: String, argumentsJSON: String) throws -> String {
        guard let handle = handleBox.current() else {
            throw JavaScriptRuntimeError.execution("QuickJS context 已释放")
        }
        host.clearBridgeError()
        setDeadline(handle)
        let arguments = argumentsJSON.utf8CString
        let result = method.withCString { methodPointer in
            arguments.withUnsafeBufferPointer { argumentsPointer in
                xg_quickjs_call(handle, methodPointer, argumentsPointer.baseAddress)
            }
        }
        guard let result else {
            if let bridgeError = host.consumeBridgeError() {
                throw JavaScriptRuntimeError.unsupported(bridgeError)
            }
            if Task.isCancelled { throw CancellationError() }
            throw executionError(lastError(handle))
        }
        defer { xg_quickjs_free_string(result) }
        if let bridgeError = host.consumeBridgeError() {
            throw JavaScriptRuntimeError.unsupported(bridgeError)
        }
        if Task.isCancelled { throw CancellationError() }
        return String(cString: result)
    }

    private func setDeadline(_ handle: OpaquePointer) {
        let deadline = Int64(Date().timeIntervalSince1970 * 1000) + Int64(timeout * 1000)
        xg_quickjs_set_deadline(handle, deadline)
    }

    private func lastError(_ handle: OpaquePointer) -> String {
        String(cString: xg_quickjs_last_error(handle))
    }

    private func scriptError(_ message: String) -> JavaScriptRuntimeError {
        if message.contains("超时") { return .timeout }
        if message.contains("取消") { return .cancelled }
        return .invalidScript(message)
    }

    private func executionError(_ message: String) -> JavaScriptRuntimeError {
        if message.contains("超时") { return .timeout }
        if message.contains("取消") { return .cancelled }
        return .execution(message)
    }
}
