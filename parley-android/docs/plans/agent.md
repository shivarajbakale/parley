# Ask Parley — the native half

`parley-a07.feature-plan.json` plans the two Flutter surfaces and the sheet's
behaviour. This plans the part that is not a Flutter surface: the Kotlin that
reads a screen, plans actions, refuses the dangerous ones, and draws the sheet
over another app.

It exists as its own document because `feature_plan.dart` draws Flutter
surfaces from the twelve archetypes, and the sheet is not one — it is a
`TYPE_ACCESSIBILITY_OVERLAY` window drawn with the orb's own Canvas and springs,
because the Flutter engine is not running when the app is closed.

## The bet

Parley already holds the one thing a screenshot-based assistant does not have.
`rootInActiveWindow` returns the actual tree — the actual text, the actual
bounds, the actual class names, no OCR, no guessing what a glyph meant. So the
agent answers from structure rather than pixels, and it can act on a node it
named rather than on a coordinate it hoped was right.

The cost is that a node tree is a bad prompt. It is deep, duplicated, full of
invisible containers, and half of it is boilerplate that means nothing to a
person. `ScreenContextSerializer` is therefore not a formatting helper — it is
the feature, and it is where the unit tests go.

## Shape

```
┌──────────────────────── Parley process ─────────────────────────┐
│                                                                 │
│  ParleyAccessibilityService                                     │
│   ├─ OrbController ── OrbView (Canvas)                          │
│   │     └── modes: idle · ask (triple-tap) · listening · sheet   │
│   ├─ FocusTracker                                                │
│   └─ Session ── Dictate │ Edit │ AgentSession                    │
│         AgentSession                                           │
│          ├─ ScreenContextSerializer  tree → List<ScreenNode>     │
│          ├─ AgentPlanner   MiniMax, JSON steps, MockWebServer    │
│          ├─ AgentPolicy    class · budget · allowlist · refuse  │
│          ├─ AgentSheetView  plan rows, per-step confirm          │
│          └─ AgentJournal   10s undo, one step back              │
│                                                                 │
│  ConfigStore (EncryptedSharedPreferences)                       │
│  HistoryStore (SQLite) ── agent entries, third mode            │
└─────────────────────────────────────────────────────────────────┘
```

## Ask mode, and why it is a mode and not a gesture

The orb already speaks three gestures: hold dictates, double-tap-hold edits,
volume tap-tap-hold dictates. A fourth *hold-like* gesture would be
unlearnable and would collide with the ones that work.

So Ask mode is a toggle: **triple-tap** puts a ring around the sphere and the
pill reads "Ask". Hold then means ask. The mode survives switching apps within
a session and expires 60 s after the last use, so a forgotten ring cannot sit
there turning a later tap into a question. The ring is the whole state — there
is nothing to read in a notification.

**The orb goes inert while a run is live.** The agent can call
`performAction(ACTION_CLICK)` on any node it can name, and the orb is a node.
A run that is about to click "Send" must not be able to click the orb, and
neither must the user. During a run the orb draws but ignores touches; the
only way to stop is the sheet's own Stop, which is reachable in one tap. Any
step whose target bounds overlap the orb's own window is refused by
`AgentPolicy` before the model is even asked.

## ScreenContextSerializer

`rootInActiveWindow` → a flat, ordered list of `ScreenNode`.

**Prune.** Drop anything not visible to the user: `visibleFraction` below 0.5
after clipping to the display bounds. Drop nodes with no label and no role of
interest — a `ViewGroup` with no text is structure the model does not need and
costs a line. Drop `isVisibleToUser == false` subtrees whole, which is usually
the biggest single win.

**Dedup.** The same label appears at every nesting level of a list row
(`TextView` → `Row` → `ItemView`). Keep the deepest node carrying the label and
drop the ancestors that inherit nothing.

**Order** by screen position, top-to-bottom then left-to-right, so the
serialised text reads in the order a person would read it.

**Budget.** Default 4,000 characters. Over budget, drop `container` roles
first, then labels under 24 characters that are not actionable, then truncate
long text to 200 characters with an ellipsis. Whatever was dropped sets
`truncated = true`, and the sheet says the answer came from part of the screen.
An agent that silently answered from half a screen is worse than one that
declines.

**Ids.** A node's id is its index in the serialised list, plus the path. It is
stable for one turn and meaningless after it, which is exactly the contract —
see *Revalidation* below.

**Never send.** Password fields (`isPassword`), the content of anything
marked as a secret, and the focused field's text when the focused field is a
search box in a browser. The `sendScreenContents` switch covers the rest, and
the sheet shows the character count of what is actually going.

## AgentPlanner

One call to MiniMax's chat completion with `response_format: json_object`,
returning an array of `AgentStep`. Re-planned after every step with the fresh
tree, capped at 5 passes, so a run recovers from a screen that did not do what
the plan assumed.

**The action set is closed:** `click`, `setText`, `scroll`, `back`, `wait`,
`answer`. A step naming an action outside it is dropped, not coerced.

**Steps are validated, not trusted.** A step whose `nodeId` is not in the
current `ScreenContext` is dropped and shown struck through. Malformed JSON
fails the run with the model's own error, never a partial plan. This is the
single most important test in the feature: a hallucinated step that gets
dropped is a non-event, and one that gets clicked is the end of the product.

## AgentPolicy — every refusal lives here, and all of it is local

The model does not decide whether an action is allowed. `AgentPolicy` does, and
it is pure functions over a step and a config, so all of it is unit-testable
with no device and no network.

| Rule | Why |
| --- | --- |
| `sendScreenContents` off → no run starts | The master switch, checked before the mic opens, like voice edit's refusal-before-recording |
| package not in `allowedPackages` → refused | An allowlist, not a denylist: a new app is unreadable until chosen, not readable until noticed |
| system UI, launcher, Parley → filtered at read time | Filtering only on write is a filter that leaks |
| node bounds overlap the orb window → refused | The agent cannot aim at its own UI |
| > 5 steps → run ends as over budget | A task this long is two confirmed runs |
| > 1 irreversible step → the extras are dropped | One irreversible thing per run, and never batched with a read |
| any irreversible step → its own confirm, naming that it cannot be undone | Labelled at the moment of the tap, not hidden in a plan five rows up |

**Classifying a step is local too.** `setText` is `write`. `click` is `write`,
unless the target is a node whose role or class matches the send/commit
patterns — which is a heuristic, so an `irreversible` classification is the
*safe* default for a click whose label matches them, and the confirm sentence
says so. When the classification is wrong it errs towards more confirmation,
which is the direction that costs one extra tap rather than one sent message.

## Revalidation

`AccessibilityNodeInfo` is not stable across a refresh. Before every step:

1. Re-serialise the tree.
2. Find the node by path. Gone → the step is `refused` with "that element
   moved", and the run re-plans.
3. Present → `performAction` on the **fresh** node object.

There is no path where a step acts on a node it resolved before the screen
changed. This is the reason ids are re-derivable from the path rather than
random.

## The sheet

Native, on the same overlay window as the orb, drawn with `OrbView`'s
`OrbMotion` springs and the Aurora type and colour tokens. The listening
capsule *becomes* the sheet: the question sits where the waveform was, the plan
settles under it, and the app behind stays visible above.

```
┌──────────────────────── the app, still there ───────────────────┐
│  Chrome                                                       │
│  ┌──────────────────────────────┐                              │
│  │ ▸ Read   Open the July invoice│  ← one row per step,        │
│  │ ▸ Write  Set the date to 12  │    graded, with the phrase   │
│  │ ▸ Send   Email it to me            in the user's words       │
│  └──────────────────────────────┘                              │
│  Chrome · 1,240 characters will be sent                         │
│  [ Run all read-only ]        [ Run this step ]                 │
└──────────────────────────────────────────────────────────────────┘
```

Dismissed by tapping the orb, by Back, or by pushing the sheet off the edge.
All three abandon the run with nothing sent and nothing done — the sheet
closing is never a silent commit.

## AgentJournal

One step of undo inside the existing 10 s window, reusing voice edit's. Before
a `setText`, the prior field text is snapshotted; before a `click` that
navigates, `back` is offered. An `irreversible` step writes **no** undo entry,
and the confirm row already said so. History keeps the run, the plan, the
outcomes and the sent context — never the raw tree after the run ends.

## Bridge additions

Per `docs/plans/bridge-contract.md` — both sides land in the same commit.

| method | args | result |
| --- | --- | --- |
| `getAgentConfig` | — | AgentConfig |
| `setAgentConfig` | AgentConfig | AgentConfig |
| `getAgentRun` | `{id: int}` | AgentRun or null |
| `listAgentRuns` | — | List\<AgentRun\> |
| `undoAgentStep` | `{runId: int, index: int}` | bool |
| `openAgentSettings` | — | null |

Event `{type: 'agent', run: AgentRun}` after every step, so Transcript streams
a live run instead of appearing at the end.

## Verification

**Kotlin, no device.** `ScreenContextSerializerTest` over captured node-tree
fixtures — a list, a form, a Chrome page, a chat thread — asserting pruning,
dedupe, ordering, the budget, and that `truncated` is set when it should be.
`AgentPolicyTest` over every row of the refusal table above.
`AgentPlannerTest` against MockWebServer: malformed JSON, a step naming an
absent node, an over-budget plan, an unknown action.
`AgentJournalTest`: the 10 s window, one step back, irreversible writes
nothing.

**Flutter.** The two pages across their four states, the not-loaded-versus-off
distinction on Agent settings, `FakeParleyBridge` carrying the new methods and
event, History's agent filter, goldens in both themes.

**Device, Oppo CPH2791, real MiniMax key, three apps** with three different
node trees (Settings, Chrome, a chat app): a question answered that used no
tool; a four-step run with one irreversible step confirmed on its own; a step
refused with its reason on screen; a run stopped mid-way. `adb screenrecord`
and screenshots under `docs/evidence/parley-a07/`.

## Risks

| Risk | Answer |
| --- | --- |
| The model clicks the wrong node on a screen that changed | Ids are re-derived from the path and revalidated before every action; a moved node refuses the step |
| The agent shoots a message on a misclassification | Irreversible is the safe default, confirmed on its own, and the confirm sentence says it cannot be undone |
| The prompt cost and latency of a 4,000-character tree | The budget is a row on a settings page, the sheet shows the count before sending, and reads are one pass |
| Reading a banking app | `sendScreenContents` off by default, per-app allowlist, and the sent context is readable in Transcript afterwards |
| A run that needs ten steps | Capped at 5; the run ends as over budget rather than wandering |
| The orb taps itself | It is inert while a run is live, and any step overlapping its window is refused before the model is asked |
