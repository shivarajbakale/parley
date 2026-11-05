import Foundation

/// The shell's side of the engine wire: newline-delimited JSON-RPC 2.0, the
/// same framing as `engine/headless/rpc.ts`. Bump both together.
public let protocolVersion = 1

public enum RPCIncoming: Sendable, Equatable {
    case request(id: JSONValue, method: String, params: JSONValue?)
    case notification(method: String, params: JSONValue?)
    case result(id: Int, value: JSONValue)
    case failure(id: Int, code: Int, message: String)
}

public struct RPCError: Error, Equatable, LocalizedError {
    public let code: Int
    public let message: String
    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
    public var errorDescription: String? { message }

    public static let handlerFailed = -32000
    public static let methodNotFound = -32601
}

public enum RPCCodec {
    public enum DecodeError: Error, Equatable {
        case notJSON
        case notAMessage
    }

    public static func decode(_ line: String) throws -> RPCIncoming {
        guard let data = line.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { throw DecodeError.notJSON }
        guard case .object(let object) = value else { throw DecodeError.notAMessage }

        if let method = object["method"]?.string {
            if let id = object["id"], id != .null {
                return .request(id: id, method: method, params: object["params"])
            }
            return .notification(method: method, params: object["params"])
        }
        guard let rawId = object["id"]?.number else { throw DecodeError.notAMessage }
        let id = Int(rawId)
        if let error = object["error"] {
            return .failure(
                id: id,
                code: Int(error["code"]?.number ?? Double(RPCError.handlerFailed)),
                message: error["message"]?.string ?? "Request failed"
            )
        }
        if let result = object["result"] { return .result(id: id, value: result) }
        throw DecodeError.notAMessage
    }

    public static func request(id: Int, method: String, params: JSONValue? = nil) -> String {
        var object: [String: JSONValue] = ["jsonrpc": "2.0", "id": .number(Double(id)), "method": .string(method)]
        if let params { object["params"] = params }
        return frame(.object(object))
    }

    public static func notification(method: String, params: JSONValue? = nil) -> String {
        var object: [String: JSONValue] = ["jsonrpc": "2.0", "method": .string(method)]
        if let params { object["params"] = params }
        return frame(.object(object))
    }

    public static func result(id: JSONValue, value: JSONValue) -> String {
        frame(["jsonrpc": "2.0", "id": id, "result": value])
    }

    public static func failure(id: JSONValue, code: Int, message: String) -> String {
        frame(["jsonrpc": "2.0", "id": id, "error": ["code": .number(Double(code)), "message": .string(message)]])
    }

    /// One line, newline-terminated. JSONEncoder escapes newlines inside
    /// strings, so a frame can never span two lines.
    static func frame(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

/// Splits a byte stream into lines. A frame may arrive in pieces, or several
/// frames in one read.
public struct LineBuffer: Sendable {
    private var pending = Data()
    public init() {}

    public mutating func append(_ chunk: Data) -> [String] {
        pending.append(chunk)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending[pending.startIndex..<newline]
            lines.append(String(decoding: line, as: UTF8.self))
            pending.removeSubrange(pending.startIndex...newline)
        }
        return lines
    }
}

/// Request/response correlation for one side of the wire. Main-actor bound:
/// every caller in the shell is UI code, and it keeps the pending table
/// free of locks.
@MainActor
public final class RPCPeer {
    public typealias RequestHandler = @MainActor (String, JSONValue?) async throws -> JSONValue
    public typealias NotifyHandler = @MainActor (String, JSONValue?) -> Void

    private let write: @MainActor (String) -> Void
    private let onRequest: RequestHandler
    private let onNotify: NotifyHandler
    private let onProtocolError: @MainActor (String) -> Void
    private let timeout: Duration
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]

    public init(
        timeout: Duration = .seconds(10),
        write: @escaping @MainActor (String) -> Void,
        onRequest: @escaping RequestHandler,
        onNotify: @escaping NotifyHandler,
        onProtocolError: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.timeout = timeout
        self.write = write
        self.onRequest = onRequest
        self.onNotify = onNotify
        self.onProtocolError = onProtocolError
    }

    public func receive(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let message: RPCIncoming
        do {
            message = try RPCCodec.decode(line)
        } catch {
            onProtocolError("unparseable line: \(line.prefix(120))")
            return
        }
        switch message {
        case .notification(let method, let params):
            onNotify(method, params)
        case .request(let id, let method, let params):
            Task { @MainActor in
                do {
                    let value = try await onRequest(method, params)
                    write(RPCCodec.result(id: id, value: value))
                } catch let error as RPCError {
                    write(RPCCodec.failure(id: id, code: error.code, message: error.message))
                } catch {
                    write(RPCCodec.failure(id: id, code: RPCError.handlerFailed, message: error.localizedDescription))
                }
            }
        case .result(let id, let value):
            guard let continuation = pending.removeValue(forKey: id) else {
                onProtocolError("response for unknown id \(id)")
                return
            }
            continuation.resume(returning: value)
        case .failure(let id, let code, let text):
            guard let continuation = pending.removeValue(forKey: id) else {
                onProtocolError("response for unknown id \(id)")
                return
            }
            continuation.resume(throwing: RPCError(code: code, message: text))
        }
    }

    public func request(_ method: String, _ params: JSONValue? = nil) async throws -> JSONValue {
        let id = nextId
        nextId += 1
        let limit = timeout
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            write(RPCCodec.request(id: id, method: method, params: params))
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: limit)
                guard let self, let waiting = self.pending.removeValue(forKey: id) else { return }
                waiting.resume(throwing: RPCError(code: RPCError.handlerFailed, message: "\(method) timed out"))
            }
        }
    }

    public func notify(_ method: String, _ params: JSONValue? = nil) {
        write(RPCCodec.notification(method: method, params: params))
    }

    /// Fails every request still waiting, e.g. when the engine exits.
    public func close(reason: String) {
        let waiting = pending
        pending.removeAll()
        for continuation in waiting.values {
            continuation.resume(throwing: RPCError(code: RPCError.handlerFailed, message: reason))
        }
    }
}
