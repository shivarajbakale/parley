import Foundation

/// The engine's types as the shell reads them. Field names match
/// `engine/types.ts`; anything the shell does not show is ignored on decode.

public enum GestureKeyName: String, CaseIterable, Codable, Sendable, Identifiable {
    case AltRight, Alt, CtrlRight, Ctrl, ShiftRight, Shift, MetaRight, Meta
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .AltRight: "Right Option ⌥"
        case .Alt: "Left Option ⌥"
        case .CtrlRight: "Right Control ⌃"
        case .Ctrl: "Left Control ⌃"
        case .ShiftRight: "Right Shift ⇧"
        case .Shift: "Left Shift ⇧"
        case .MetaRight: "Right Command ⌘"
        case .Meta: "Left Command ⌘"
        }
    }

    public var short: String {
        let side = rawValue.hasSuffix("Right") ? "Right" : "Left"
        let symbol = switch self {
        case .AltRight, .Alt: "⌥"
        case .CtrlRight, .Ctrl: "⌃"
        case .ShiftRight, .Shift: "⇧"
        case .MetaRight, .Meta: "⌘"
        }
        return "\(side) \(symbol)"
    }
}

public struct AgentMcpServer: Codable, Equatable, Sendable, Identifiable {
    public var name: String
    public var tools: Int
    public var id: String { name }
}

public struct AgentCurrentRun: Codable, Equatable, Sendable {
    public var status: String
    public var summary: String
    public var callId: String?
}

public struct AgentSummary: Codable, Equatable, Sendable {
    public var online: Bool
    public var managed: Bool
    public var serverState: String
    public var message: String
    public var currentRun: AgentCurrentRun?
    public var mcpServers: [AgentMcpServer]

    public static let offline = AgentSummary(
        online: false, managed: false, serverState: "offline", message: "", currentRun: nil, mcpServers: [])
}

public struct SettingsView: Codable, Equatable, Sendable {
    public var gestureKey: GestureKeyName
    public var tapCount: Int
    public var editGestureKey: GestureKeyName
    public var explainGestureKey: GestureKeyName
    public var actGestureKey: GestureKeyName
    public var agentUrl: String
    public var agentAutoStart: Bool
    public var syncEnabled: Bool
    public var syncUrl: String
    public var syncEmail: String
    public var vocabulary: String
    public var transcriptionProvider: String
    public var tickSound: Bool
    public var launchAtLogin: Bool
    public var onboardingComplete: Bool
    public var wordsDictated: Int
    public var hasSyncToken: Bool
    public var syncLastAt: Double
    public var syncLastError: String
    public var agent: AgentSummary
}

public struct DictionaryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var word: String
    public var soundsLike: [String]
    public var uses: Int?
    public var source: String?
}

public struct ServerStatus: Codable, Equatable, Sendable {
    public struct Keys: Codable, Equatable, Sendable {
        public var groq: Bool
        public var deepgram: Bool
        public var minimax: Bool
    }
    public var reachable: Bool
    public var url: String
    public var keys: Keys?
}

public struct ExplainSource: Codable, Equatable, Sendable, Hashable {
    public var title: String
    public var url: String
}

public struct ExplainTurn: Codable, Equatable, Sendable {
    public var question: String?
    /// loading, streaming, ready or error.
    public var status: String
    public var markdown: String?
    public var message: String?
    public var searching: String?
    public var sources: [ExplainSource]?
}

public struct ExplainContent: Codable, Equatable, Sendable {
    /// empty or thread.
    public var status: String
    public var turns: [ExplainTurn]?

    public static let empty = ExplainContent(status: "empty", turns: nil)
}

public enum JSONBridge {
    /// Decodes a wire value into a model; nil when it does not fit.
    public static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue?) -> T? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public static func encode<T: Encodable>(_ model: T) -> JSONValue {
        guard let data = try? JSONEncoder().encode(model),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return .null }
        return value
    }
}
