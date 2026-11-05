import Foundation
import Testing
@testable import ParleyCore

@Suite struct RPCCodecTests {
    @Test func framesAreOneNewlineTerminatedLine() {
        let line = RPCCodec.notification(method: "key", params: ["text": "a\nb"])
        #expect(line.hasSuffix("\n"))
        #expect(!line.dropLast().contains("\n"))
    }

    @Test func roundTripsARequest() throws {
        let line = RPCCodec.request(id: 4, method: "hello", params: ["protocolVersion": 1])
        let decoded = try RPCCodec.decode(line)
        #expect(decoded == .request(id: 4, method: "hello", params: ["protocolVersion": 1]))
    }

    @Test func decodesWhatTheEngineSends() throws {
        // Exact frames from engine/headless/rpc.ts.
        #expect(try RPCCodec.decode(#"{"jsonrpc":"2.0","method":"hud.phase","params":{"phase":"listening","tick":true}}"#)
            == .notification(method: "hud.phase", params: ["phase": "listening", "tick": true]))
        #expect(try RPCCodec.decode(#"{"jsonrpc":"2.0","id":1,"method":"paste.text","params":{"text":"hi"}}"#)
            == .request(id: 1, method: "paste.text", params: ["text": "hi"]))
        #expect(try RPCCodec.decode(#"{"jsonrpc":"2.0","id":2,"result":{"engineVersion":"0.6.4"}}"#)
            == .result(id: 2, value: ["engineVersion": "0.6.4"]))
        #expect(try RPCCodec.decode(#"{"jsonrpc":"2.0","id":3,"error":{"code":-32600,"message":"Protocol mismatch"}}"#)
            == .failure(id: 3, code: -32600, message: "Protocol mismatch"))
    }

    @Test func rejectsGarbage() {
        #expect(throws: RPCCodec.DecodeError.notJSON) { try RPCCodec.decode("{nope") }
        #expect(throws: RPCCodec.DecodeError.notAMessage) { try RPCCodec.decode("[1]") }
        #expect(throws: RPCCodec.DecodeError.notAMessage) { try RPCCodec.decode(#"{"jsonrpc":"2.0"}"#) }
    }
}

@Suite struct LineBufferTests {
    @Test func joinsSplitFramesAndSplitsJoinedOnes() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data(#"{"a":"#.utf8)) == [])
        #expect(buffer.append(Data("1}\n{\"b\":2}\n{\"c\"".utf8)) == [#"{"a":1}"#, #"{"b":2}"#])
        #expect(buffer.append(Data(":3}\n".utf8)) == [#"{"c":3}"#])
    }

    @Test func keepsMultibyteCharactersSplitAcrossReads() {
        var buffer = LineBuffer()
        let bytes = Array("é\n".utf8)
        #expect(buffer.append(Data(bytes[0..<1])) == [])
        #expect(buffer.append(Data(bytes[1...])) == ["é"])
    }
}

@MainActor
@Suite struct RPCPeerTests {
    final class Wire {
        var lines: [String] = []
    }

    func makePeer(
        wire: Wire,
        timeout: Duration = .seconds(5),
        onRequest: @escaping RPCPeer.RequestHandler = { _, _ in .null },
        onNotify: @escaping RPCPeer.NotifyHandler = { _, _ in }
    ) -> RPCPeer {
        RPCPeer(timeout: timeout, write: { wire.lines.append($0) }, onRequest: onRequest, onNotify: onNotify)
    }

    @Test func correlatesResponsesOutOfOrder() async throws {
        let wire = Wire()
        let peer = makePeer(wire: wire)
        async let first = peer.request("a")
        async let second = peer.request("b")
        while wire.lines.count < 2 { await Task.yield() }
        let ids = try wire.lines.map { line -> Int in
            guard case .request(let id, _, _) = try RPCCodec.decode(line) else { return -1 }
            return Int(id.number ?? -1)
        }
        peer.receive(RPCCodec.result(id: .number(Double(ids[1])), value: "B"))
        peer.receive(RPCCodec.result(id: .number(Double(ids[0])), value: "A"))
        let values = try await [first, second]
        #expect(Set(values) == Set(["A", "B"]))
    }

    @Test func surfacesTheOtherSidesError() async {
        let wire = Wire()
        let peer = makePeer(wire: wire)
        let reply = Task { try await peer.request("hello") }
        while wire.lines.isEmpty { await Task.yield() }
        peer.receive(RPCCodec.failure(id: 1, code: -32600, message: "Protocol mismatch"))
        await #expect(throws: RPCError(code: -32600, message: "Protocol mismatch")) { try await reply.value }
    }

    @Test func timesOut() async {
        let wire = Wire()
        let peer = makePeer(wire: wire, timeout: .milliseconds(20))
        await #expect(throws: RPCError.self) { try await peer.request("paste.text") }
    }

    @Test func answersIncomingRequests() async throws {
        let wire = Wire()
        let peer = makePeer(wire: wire, onRequest: { method, params in
            #expect(method == "paste.text")
            return ["ok": true, "echo": params?["text"] ?? .null]
        })
        peer.receive(#"{"jsonrpc":"2.0","id":9,"method":"paste.text","params":{"text":"hi"}}"#)
        while wire.lines.isEmpty { await Task.yield() }
        #expect(try RPCCodec.decode(wire.lines[0]) == .result(id: 9, value: ["ok": true, "echo": "hi"]))
    }

    @Test func answersAThrowingHandlerWithAnError() async throws {
        let wire = Wire()
        let peer = makePeer(wire: wire, onRequest: { _, _ in
            throw RPCError(code: RPCError.methodNotFound, message: "nope")
        })
        peer.receive(#"{"jsonrpc":"2.0","id":2,"method":"x"}"#)
        while wire.lines.isEmpty { await Task.yield() }
        #expect(try RPCCodec.decode(wire.lines[0]) == .failure(id: 2, code: RPCError.methodNotFound, message: "nope"))
    }

    @Test func routesNotifications() {
        let wire = Wire()
        var seen: [String] = []
        let peer = makePeer(wire: wire, onNotify: { method, _ in seen.append(method) })
        peer.receive(#"{"jsonrpc":"2.0","method":"hud.show"}"#)
        #expect(seen == ["hud.show"])
        #expect(wire.lines.isEmpty)
    }

    @Test func closeFailsEveryWaitingRequest() async {
        let wire = Wire()
        let peer = makePeer(wire: wire)
        let reply = Task { try await peer.request("paste.text") }
        while wire.lines.isEmpty { await Task.yield() }
        peer.close(reason: "engine exited")
        await #expect(throws: RPCError(code: RPCError.handlerFailed, message: "engine exited")) { try await reply.value }
    }
}
