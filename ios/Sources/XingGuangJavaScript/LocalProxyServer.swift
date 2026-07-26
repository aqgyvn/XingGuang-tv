import Foundation
import Network

public final class JavaScriptProxyEndpoint: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: URL?

    public init(value: URL? = nil) {
        storedValue = value
    }

    public var value: URL? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

public enum LocalProxyServerError: Error, LocalizedError {
    case noAvailablePort

    public var errorDescription: String? {
        "本地代理端口 9978-9998 均不可用"
    }
}

public final class LocalProxyServer: @unchecked Sendable {
    private let repository: JavaScriptVodRepository
    private let queue = DispatchQueue(label: "com.xingguang.video.ios.local-proxy")
    private let lock = NSLock()
    private var listener: NWListener?
    private var connections: Set<ObjectIdentifier> = []

    public init(repository: JavaScriptVodRepository) {
        self.repository = repository
    }

    public func start() async throws -> URL {
        if let port = listener?.port?.rawValue {
            return URL(string: "http://127.0.0.1:\(port)/proxy")!
        }
        for rawPort in UInt16(9978)...UInt16(9998) {
            do {
                let listener = try await makeListener(port: rawPort)
                self.listener = listener
                let endpoint = URL(string: "http://127.0.0.1:\(rawPort)/proxy")!
                repository.setProxyEndpoint(endpoint)
                return endpoint
            } catch {
                continue
            }
        }
        throw LocalProxyServerError.noAvailablePort
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func makeListener(port rawPort: UInt16) async throws -> NWListener {
        guard let port = NWEndpoint.Port(rawValue: rawPort) else { throw LocalProxyServerError.noAvailablePort }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            listener.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener)
                case .failed(let error):
                    resumed = true
                    listener.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: LocalProxyServerError.noAvailablePort)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    private func accept(_ connection: NWConnection) {
        let identifier = ObjectIdentifier(connection)
        lock.lock()
        guard connections.count < 8 else {
            lock.unlock()
            connection.start(queue: queue)
            send(status: 503, body: Data("busy".utf8), headers: [:], headOnly: false, connection: connection)
            return
        }
        connections.insert(identifier)
        lock.unlock()
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish(connection) }
            if case .cancelled = state { self?.finish(connection) }
        }
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            guard let self else { return }
            var buffer = accumulated
            if let data { buffer.append(data) }
            guard buffer.count <= 32_768 else {
                self.send(status: 413, body: Data(), headers: [:], headOnly: false, connection: connection)
                return
            }
            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil || complete || error != nil {
                self.handle(buffer, connection: connection)
            } else {
                self.receive(on: connection, accumulated: buffer)
            }
        }
    }

    private func handle(_ data: Data, connection: NWConnection) {
        guard let text = String(data: data, encoding: .utf8),
              let firstLine = text.components(separatedBy: "\r\n").first else {
            send(status: 400, body: Data(), headers: [:], headOnly: false, connection: connection)
            return
        }
        let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count == 3, ["GET", "HEAD"].contains(parts[0]) else {
            send(status: 405, body: Data(), headers: [:], headOnly: false, connection: connection)
            return
        }
        guard parts[1].count <= 16_384,
              let components = URLComponents(string: "http://127.0.0.1" + parts[1]),
              components.path == "/proxy" else {
            send(status: 404, body: Data(), headers: [:], headOnly: parts[0] == "HEAD", connection: connection)
            return
        }
        let parameters = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard parameters["do"] == "js" else {
            send(status: 400, body: Data(), headers: [:], headOnly: parts[0] == "HEAD", connection: connection)
            return
        }
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.repository.proxy(parameters: parameters)
                self.send(
                    status: min(max(response.statusCode, 100), 599),
                    body: response.data,
                    headers: response.headers.merging(["Content-Type": response.contentType]) { current, _ in current },
                    headOnly: parts[0] == "HEAD",
                    connection: connection
                )
            } catch {
                self.send(status: 502, body: Data(error.localizedDescription.utf8), headers: ["Content-Type": "text/plain; charset=utf-8"], headOnly: parts[0] == "HEAD", connection: connection)
            }
        }
    }

    private func send(status: Int, body: Data, headers: [String: String], headOnly: Bool, connection: NWConnection) {
        let reason = HTTPURLResponse.localizedString(forStatusCode: status)
        var lines = ["HTTP/1.1 \(status) \(reason)", "Connection: close", "Content-Length: \(body.count)"]
        for (key, value) in headers where !key.contains("\r") && !key.contains("\n") && !value.contains("\r") && !value.contains("\n") {
            lines.append("\(key): \(value)")
        }
        var response = Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        if !headOnly { response.append(body) }
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.finish(connection)
        })
    }

    private func finish(_ connection: NWConnection) {
        lock.lock()
        connections.remove(ObjectIdentifier(connection))
        lock.unlock()
        connection.stateUpdateHandler = nil
    }
}
