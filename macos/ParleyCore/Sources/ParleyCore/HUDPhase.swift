/// What the engine's `hud.phase` says, and what the recorder does about it.
/// Mirrors the old Electron orb's phase handler: the session in
/// the engine waits on exactly one `audio.ready` after `transcribing`, so the
/// shell must answer every `transcribing`, even with nothing recorded.
public struct HUDPhase: Equatable, Sendable {
    public enum Phase: String, Sendable {
        case listening, transcribing, done, error, cancelled, notice
    }

    public let phase: Phase
    public let message: String?
    /// With `notice`: the smaller line that says how to answer.
    public let hint: String?
    /// With `notice`: the answer was yes.
    public let accepted: Bool
    /// With `listening`: edit, explain or act; nil is dictation.
    public let mode: String?
    public let tick: Bool

    public init(phase: Phase, message: String? = nil, hint: String? = nil, accepted: Bool = false,
                mode: String? = nil, tick: Bool = false) {
        self.phase = phase
        self.message = message
        self.hint = hint
        self.accepted = accepted
        self.mode = mode
        self.tick = tick
    }

    public init?(_ params: JSONValue?) {
        guard let raw = params?["phase"]?.string, let phase = Phase(rawValue: raw) else { return nil }
        self.init(
            phase: phase,
            message: params?["message"]?.string,
            hint: params?["hint"]?.string,
            accepted: params?["accepted"]?.bool ?? false,
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
