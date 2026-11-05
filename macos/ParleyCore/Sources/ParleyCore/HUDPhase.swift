/// What the engine's `hud.phase` says, and what the recorder does about it.
/// Mirrors `src/orb/phase-handler.ts`, which this replaces: the session in
/// the engine waits on exactly one `audio.ready` after `transcribing`, so the
/// shell must answer every `transcribing`, even with nothing recorded.
public struct HUDPhase: Equatable, Sendable {
    public enum Phase: String, Sendable {
        case listening, transcribing, done, error, cancelled, notice
    }

    public let phase: Phase
    public let message: String?
    public let mode: String?
    public let tick: Bool

    public init(phase: Phase, message: String? = nil, mode: String? = nil, tick: Bool = false) {
        self.phase = phase
        self.message = message
        self.mode = mode
        self.tick = tick
    }

    public init?(_ params: JSONValue?) {
        guard let raw = params?["phase"]?.string, let phase = Phase(rawValue: raw) else { return nil }
        self.init(
            phase: phase,
            message: params?["message"]?.string,
            mode: params?["mode"]?.string,
            tick: params?["tick"]?.bool ?? false
        )
    }
}

public enum RecorderAction: Equatable, Sendable {
    case start
    /// Stop and hand the take to the engine (an empty take if none).
    case stopAndSend
    case discard
    case none
}

public func recorderAction(for phase: HUDPhase.Phase, isRecording: Bool) -> RecorderAction {
    switch phase {
    case .listening:
        return .start
    case .transcribing:
        return .stopAndSend
    case .cancelled, .error:
        return isRecording ? .discard : .none
    case .done, .notice:
        return .none
    }
}
