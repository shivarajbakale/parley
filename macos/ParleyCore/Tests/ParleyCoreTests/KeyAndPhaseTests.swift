import AppKit
import Testing
@testable import ParleyCore

@Suite struct ModifierTrackerTests {
    @Test func rightOptionDownAndUp() {
        var tracker = ModifierTracker()
        // Right Option down: device bit 0x40 plus the generic alternate mask.
        #expect(tracker.flagsChanged(keyCode: 61, flags: 0x0008_0040) == KeyTransition(.down, "AltRight"))
        #expect(tracker.flagsChanged(keyCode: 61, flags: 0x0000_0100) == KeyTransition(.up, "AltRight"))
    }

    @Test func tellsLeftFromRight() {
        var tracker = ModifierTracker()
        #expect(tracker.flagsChanged(keyCode: 58, flags: 0x0008_0020) == KeyTransition(.down, "Alt"))
        // Right Option goes down while left is held: both bits set.
        #expect(tracker.flagsChanged(keyCode: 61, flags: 0x0008_0060) == KeyTransition(.down, "AltRight"))
        // Left released, right still held.
        #expect(tracker.flagsChanged(keyCode: 58, flags: 0x0008_0040) == KeyTransition(.up, "Alt"))
        #expect(tracker.flagsChanged(keyCode: 61, flags: 0) == KeyTransition(.up, "AltRight"))
    }

    @Test func everyGestureKeyHasItsName() {
        let expected: [UInt16: String] = [
            58: "Alt", 61: "AltRight", 59: "Ctrl", 62: "CtrlRight",
            56: "Shift", 60: "ShiftRight", 55: "Meta", 54: "MetaRight",
        ]
        for (code, name) in expected {
            var tracker = ModifierTracker()
            let mask = KeyMap.modifiers[code]!.mask
            #expect(tracker.flagsChanged(keyCode: code, flags: mask) == KeyTransition(.down, name))
        }
    }

    @Test func repeatedEdgesAreReportedOnce() {
        var tracker = ModifierTracker()
        #expect(tracker.flagsChanged(keyCode: 54, flags: 0x10) != nil)
        #expect(tracker.flagsChanged(keyCode: 54, flags: 0x10) == nil)
        #expect(tracker.flagsChanged(keyCode: 54, flags: 0) != nil)
        #expect(tracker.flagsChanged(keyCode: 54, flags: 0) == nil)
    }

    @Test func otherModifiersReadAsOther() {
        var tracker = ModifierTracker()
        // Caps Lock (57) and Fn (63).
        #expect(tracker.flagsChanged(keyCode: 57, flags: 0x0001_0000) == KeyTransition(.down, "Other"))
        #expect(tracker.flagsChanged(keyCode: 63, flags: 0x0080_0000) == KeyTransition(.down, "Other"))
    }

    @Test func plainKeys() {
        #expect(KeyMap.key(.down, keyCode: 53) == KeyTransition(.down, "Escape"))
        #expect(KeyMap.key(.up, keyCode: 0) == KeyTransition(.up, "Other"))
    }
}

@Suite struct HUDPhaseTests {
    @Test func parsesTheEnginePayload() {
        let phase = HUDPhase(["phase": "error", "message": "Parley server not running"])
        #expect(phase == HUDPhase(phase: .error, message: "Parley server not running"))
        #expect(HUDPhase(["phase": "listening", "tick": true])?.tick == true)
        #expect(HUDPhase(["phase": "dancing"]) == nil)
        let offer = HUDPhase(["phase": "notice", "message": "Remember Mastra?", "hint": "Tap to keep it", "accepted": true])
        #expect(offer?.hint == "Tap to keep it")
        #expect(offer?.accepted == true)
        #expect(HUDPhase(["phase": "listening", "mode": "edit"])?.mode == "edit")
        #expect(HUDPhase(nil) == nil)
    }

    @Test func recorderFollowsThePhase() {
        #expect(recorderAction(for: .listening, isRecording: false) == .start)
        // Always answered, recording or not: the engine waits on it.
        #expect(recorderAction(for: .transcribing, isRecording: true) == .stopAndSend)
        #expect(recorderAction(for: .transcribing, isRecording: false) == .stopAndSend)
        #expect(recorderAction(for: .cancelled, isRecording: true) == .discard)
        #expect(recorderAction(for: .cancelled, isRecording: false) == .none)
        #expect(recorderAction(for: .error, isRecording: true) == .discard)
        #expect(recorderAction(for: .done, isRecording: false) == .none)
    }
}

@MainActor
@Suite struct PasterTests {
    func board() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("parley-test-\(UUID().uuidString)"))
        board.clearContents()
        return board
    }

    func seed(_ board: NSPasteboard) {
        let item = NSPasteboardItem()
        item.setString("original", forType: .string)
        item.setString("<b>original</b>", forType: .html)
        board.writeObjects([item])
    }

    @Test func pastesThenRestoresEveryType() async {
        let board = board()
        defer { board.releaseGlobally() }
        seed(board)
        var keys: [Keystroke] = []
        var seenAtPaste: String?
        let paster = Paster(pasteboard: board, send: { key in
            keys.append(key)
            if key == .paste { seenAtPaste = board.string(forType: .string) }
        }, sleep: { _ in })
        await paster.paste("dictated text")
        #expect(keys == [.paste])
        #expect(seenAtPaste == "dictated text")
        #expect(board.string(forType: .string) == "original")
        #expect(board.string(forType: .html) == "<b>original</b>")
    }

    @Test func pasteOverTheWholeFieldSelectsAllFirst() async {
        let board = board()
        defer { board.releaseGlobally() }
        var keys: [Keystroke] = []
        let paster = Paster(pasteboard: board, send: { keys.append($0) }, sleep: { _ in })
        await paster.paste("rewritten", selectAll: true)
        #expect(keys == [.selectAll, .paste])
    }

    @Test func copyAllReadsWhatTheAppCopiedAndRestores() async {
        let board = board()
        defer { board.releaseGlobally() }
        seed(board)
        var keys: [Keystroke] = []
        let paster = Paster(pasteboard: board, send: { key in
            keys.append(key)
            // The app answers ⌘C by putting the field on the pasteboard.
            if key == .copy {
                board.clearContents()
                board.setString("whole field", forType: .string)
            }
        }, sleep: { _ in })
        #expect(await paster.copyAll() == "whole field")
        #expect(keys == [.selectAll, .copy])
        #expect(board.string(forType: .string) == "original")
    }

    @Test func copySelectionThatCopiesNothingReadsAsNothing() async {
        let board = board()
        defer { board.releaseGlobally() }
        seed(board)
        let paster = Paster(pasteboard: board, send: { _ in }, sleep: { _ in })
        #expect(await paster.copySelection() == "")
        #expect(board.string(forType: .string) == "original")
    }

    @Test func eraseSendsOneBackspacePerCharacterInBatches() async {
        let board = board()
        defer { board.releaseGlobally() }
        var keys: [Keystroke] = []
        var pauses = 0
        let paster = Paster(pasteboard: board, send: { keys.append($0) }, sleep: { _ in pauses += 1 })
        await paster.erase(120)
        #expect(keys.count == 120)
        #expect(keys.allSatisfy { $0 == .backspace })
        #expect(pauses == 3)
        await paster.erase(0)
        #expect(keys.count == 120)
    }

    @Test func anEmptyClipboardStaysEmpty() async {
        let board = board()
        defer { board.releaseGlobally() }
        let paster = Paster(pasteboard: board, send: { _ in }, sleep: { _ in })
        await paster.paste("x")
        #expect(board.string(forType: .string) == nil)
    }
}
