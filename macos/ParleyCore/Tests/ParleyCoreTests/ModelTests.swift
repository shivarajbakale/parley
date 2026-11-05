import Foundation
import Testing
@testable import ParleyCore

@Suite struct ModelTests {
    /// Exactly what `store.view(OFFLINE_AGENT_SUMMARY)` prints for a fresh store.
    let freshView = #"{"gestureKey":"AltRight","tapCount":3,"editGestureKey":"MetaRight","explainGestureKey":"CtrlRight","actGestureKey":"ShiftRight","agentUrl":"http://localhost:4111","agentAutoStart":true,"syncEnabled":false,"syncUrl":"http://localhost:3100","syncEmail":"","vocabulary":"","transcriptionProvider":"groq","tickSound":true,"launchAtLogin":true,"tourSeen":false,"wizardStep":0,"onboardingComplete":false,"wordsDictated":0,"hasSyncToken":false,"syncLastAt":0,"syncLastError":"","agent":{"online":false,"managed":false,"serverState":"offline","message":"","currentRun":null,"mcpServers":[]}}"#

    func wire(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test func decodesTheEnginesSettingsView() throws {
        let view = try #require(JSONBridge.decode(SettingsView.self, from: try wire(freshView)))
        #expect(view.gestureKey == .AltRight)
        #expect(view.editGestureKey == .MetaRight)
        #expect(view.tapCount == 3)
        #expect(view.agent == .offline)
    }

    @Test func decodesADictionaryEntryWithExtraFields() throws {
        let entry = try #require(JSONBridge.decode(DictionaryEntry.self, from: try wire(
            #"{"id":"a1","word":"Mastra","soundsLike":["master"],"uses":4,"lastUsedAt":1,"updatedAt":2}"#)))
        #expect(entry.word == "Mastra")
        #expect(entry.uses == 4)
    }

    @Test func decodesAnExplainThread() throws {
        let content = try #require(JSONBridge.decode(ExplainContent.self, from: try wire(
            #"{"status":"thread","turns":[{"status":"ready","markdown":"**Idempotent** means…","sources":[{"title":"MDN","url":"https://developer.mozilla.org"}]},{"question":"why?","status":"loading","searching":"idempotent http"}]}"#)))
        #expect(content.turns?.count == 2)
        #expect(content.turns?[0].sources?.first?.title == "MDN")
        #expect(content.turns?[1].searching == "idempotent http")
    }

    @Test func gestureKeyLabels() {
        #expect(GestureKeyName.AltRight.short == "Right ⌥")
        #expect(GestureKeyName.Shift.short == "Left ⇧")
        #expect(GestureKeyName.allCases.count == 8)
    }
}
