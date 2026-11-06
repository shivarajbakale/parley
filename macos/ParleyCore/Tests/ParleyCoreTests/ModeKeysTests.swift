import Testing
@testable import ParleyCore

@Suite struct ModeKeysTests {
    let keys: [String: GestureKeyName] = [
        "gestureKey": .Shift, "editGestureKey": .ShiftRight, "explainGestureKey": .MetaRight, "actGestureKey": .AltRight,
    ]

    @Test func aFreeKeyChangesOneMode() {
        #expect(ModeKeys.assign(.Ctrl, to: "actGestureKey", current: keys) == ["actGestureKey": .Ctrl])
    }

    @Test func aTakenKeySwapsTheTwoModes() {
        #expect(ModeKeys.assign(.MetaRight, to: "editGestureKey", current: keys)
            == ["editGestureKey": .MetaRight, "explainGestureKey": .ShiftRight])
    }

    @Test func theSameKeyChangesNothing() {
        #expect(ModeKeys.assign(.Shift, to: "gestureKey", current: keys).isEmpty)
    }

    @Test func anExistingDuplicateIsResolvedWithAFreeKey() {
        var dup = keys
        dup["actGestureKey"] = .ShiftRight // same as Voice edit
        // Act takes Explain's key; Explain can't get ShiftRight back (Voice edit has it).
        let patch = ModeKeys.assign(.MetaRight, to: "actGestureKey", current: dup)
        #expect(patch["actGestureKey"] == .MetaRight)
        let explain = try! #require(patch["explainGestureKey"])
        #expect(![.Shift, .ShiftRight, .MetaRight].contains(explain))
    }

    @Test func keyCodesNameModifiersOnly() {
        #expect(GestureKeyName(keyCode: 61) == .AltRight)
        #expect(GestureKeyName(keyCode: 56) == .Shift)
        #expect(GestureKeyName(keyCode: 0) == nil)
        #expect(GestureKeyName.MetaRight.name == "Right Command")
    }
}
