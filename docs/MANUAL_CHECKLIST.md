# Manual checklist

The global key hook, the paste keystroke and macOS permissions cannot be
automated. Walk this list with `make dev` before calling a release good.

## Paste targets

Dictate one sentence into each and confirm the text lands at the cursor and the
previous clipboard content is back afterwards (copy a word first, paste it after).

- [ ] Safari (a web text area)
- [ ] Chrome (a web text area)
- [ ] Slack (message box)
- [ ] VS Code (editor)
- [ ] Terminal
- [ ] Notes

## Gesture

- [ ] Option+letter shortcuts and single Option taps never show the orb.
- [ ] Tap, tap, hold shows the orb; release pastes.
- [ ] Esc while holding cancels; nothing is pasted.
- [ ] A press shorter than 300 ms of audio pastes nothing.
- [ ] A second gesture during transcription is ignored.
- [ ] At the 10-minute auto-stop the gesture modifier is still physically held,
      so the injected Cmd+V may arrive as Cmd+Option+V (or Cmd+Shift+V) and do
      nothing or the wrong thing. Hold past the auto-stop and confirm the
      transcript still lands in the target app.
- [ ] Changing the gesture key in Settings and performing the new gesture
      works; the old key no longer shows the orb.
- [ ] Changing the tap count in Settings and performing the new gesture works.

## Window intelligence

- [ ] With two displays: put a text field on the second display, move the
      mouse cursor back to the first, and perform the gesture without moving
      the mouse. The orb appears above the Dock on the display holding the
      window, not the one holding the cursor.
- [ ] With one display, the orb still appears in its usual spot regardless of
      which app is frontmost.

## Onboarding from a clean state

- [ ] `tccutil reset Accessibility` and `tccutil reset Microphone`, delete
      `~/Library/Application Support/parley/settings.json`, relaunch: the settings
      window opens with the "Finish setup" banner.
- [ ] Each Grant button leads to the right prompt or System Settings pane.
- [ ] Badges turn to "Granted" without restarting the app.
- [ ] Clicking each "open System Settings" button actually lands on the right
      Privacy pane on macOS 26. The deep links currently used are the older
      form, `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`
      and `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
      If either fails to open the correct pane on the machine under test, note
      it here and try the newer form as a replacement:
      `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone`
      and `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility`.

## First-run flow

From a clean state (delete `~/Library/Application Support/parley/settings.json`, relaunch):

- [ ] Welcome opens, not the tour: the three modes with violet, amber and cyan dots; Get started goes to the microphone. There is no Back on Welcome.
- [ ] Mic screen: grant, then the live orb follows your voice for ~3 s and the screen auto-continues. Back returns to Welcome.
- [ ] Accessibility: the button opens the right System Settings pane; toggling Parley on auto-continues after the beat. The Missing badge and Grant button are tinted, not black, in dark mode.
- [ ] Transcription: "Get a free key" opens console.groq.com in the browser; an invalid key shows an inline error and stores nothing; a valid key shows "Key works" and then Continue. There is no MiniMax screen after it.
- [ ] Gesture trainer: each tap lights a key cap, the last cap fills while held, and the finished gesture turns all caps teal with "That’s the gesture ✓".
- [ ] Gesture trainer misses: a slow tap says "That tap was a hold"; a long pause between taps says "Too slow between taps"; letting go of the hold early says "Hold the last press a moment longer".
- [ ] Gesture trainer: Capture plus pressing Right Command sets the key and the caps redraw with ⌘; pressing "A" shows "Modifiers only"; More keys opens the voice edit, Explain and presses rows.
- [ ] First words: hold the gesture, speak, release — the text lands in the sandbox and "It landed" shows. Finish with an empty box nudges instead of advancing.
- [ ] Finale: the orb rests, then flies onto the drawn menu bar strip, and the Scene is teal. Only missing items are listed, each with Re-open step. Start using Parley lands on the tabs; Take the tour plays the tour, then lands on the tabs.
- [ ] The real menu bar shows ◉, and clicking it offers Settings.
- [ ] Quit mid-flow (e.g. on Transcription) and relaunch: it resumes on the same screen. The tour never shows on its own.
- [ ] With Reduce Motion on: the ring, the Scene tone and the finale orb change with no animation; the trainer's hold cap fills at once.
- [ ] Keyboard-only: every screen completes without a pointer; focus lands on each heading.
- [ ] Existing users mid-wizard on 0.3.0: they resume at their stored step number, which may be one screen off from where they left. Nothing breaks.

## MiniMax on first use

With no MiniMax key stored and onboarding complete:

- [ ] Settings window closed: the voice edit gesture opens it with the "Voice edit and Explain need MiniMax" dialog already showing.
- [ ] Settings window open and in front: the same gesture shows the dialog over the current tab.
- [ ] The Explain gesture does the same.
- [ ] A bad key shows MiniMax's reason in red and the dialog stays; a good key shows "Try the gesture again" and the dialog closes itself; the gesture then works.
- [ ] Not now (the close button) dismisses it; dictation keeps working without a key.

## Settings Overview

After onboarding:

- [ ] The settings window opens on Overview. With everything granted it reads "Parley is ready" and names your gesture.
- [ ] Time saved starts as "Your first dictation starts the count." Dictate two sentences, reopen or refocus the window, and the words count and the minutes rise. Voice edit and Explain do not add to it.
- [ ] Quit and relaunch: the count survives.
- [ ] Revoke Accessibility in System Settings: within two seconds the title turns to "Finish setup", the row shows Grant Accessibility, and the rail says Setup needed. The button fixes it.
- [ ] Replace on the transcription key opens its form inline; a good key shows "Key works". Add on the MiniMax row does the same for MiniMax.
- [ ] Gesture and General are grouped lists (Keys, Timing; Behaviour, Dictation, Help) with hairlines between rows; every control still saves at once, and vocabulary saves on blur.
- [ ] The rail labels sit left beside their icons, and the rail orb sits in line with "Parley".

## Groq API key

- [ ] Entering a real Groq API key in Settings and saving it succeeds and the
      key test passes.
- [ ] Entering an invalid key shows an inline error message and the key is
      not stored.

## Errors

- [ ] Wi-Fi off: the orb turns red with "No connection" for 3 s; nothing is
      pasted; the clipboard is unchanged.
- [ ] Invalid stored key: the orb shows "Invalid API key".

## Menu bar

- [ ] No dock icon. The tray shows the status line.
- [ ] "Copy last transcript" is disabled until the first dictation, then
      copies the last transcript to the clipboard.
- [ ] Launch at login appears in System Settings, General, Login Items.
- [ ] Quitting from the tray menu quits the app; the tray icon disappears.
- [ ] Launching a second instance of the app (while the first is still
      running) does not create a second tray item and does not install a
      second global key hook; the second instance quits immediately.

## Settings errors

- [ ] Forcing an IPC mutation (settings update, API key save, permission
      request) to reject shows an inline error Alert in the settings window
      instead of a silent failure or a crash.

## Offline behaviour

- [ ] With no network connection, dictating leaves the system clipboard
      exactly as it was before the gesture (nothing partially copied or
      pasted).

## Packaged build

- [ ] Recording works in a packaged, hardened-runtime build. If the microphone
      is silent there while it works under `make dev`, the hardened runtime is
      denying capture: add an entitlements plist granting
      `com.apple.security.device.audio-input` and point `electron-builder.json5`
      at it, then re-test.

## Orb and settings visuals

- [ ] Hold the gesture: the pill grows from a dot above the Dock with a
      small bounce, and its bars follow the voice.
- [ ] The pill reads as tinted glass, not black, and its glow is never cut
      off by the window edge, over light and dark wallpapers.
- [ ] Release: a crest sweeps the bars while transcribing, the pill flashes
      teal and folds back to a dot. The text field keeps focus throughout.
- [ ] Dictation is indigo; voice edit is lilac; an error is red with its
      message above the pill.
- [ ] With sounds on: a rising glass pair on start, the same pair falling on
      release, a soft chord on done. Voice edit plays them higher.
- [ ] Settings opens with no white flash; wallpaper blurs through the glass.
- [ ] The tab pill slides; tab content slides in the direction of travel.
- [ ] With Reduce Motion on, the app uses fades only and the bars drift
      slower.


### Orb and pill polish (parley-011)

- [ ] Dictate a sentence: the pill pops (a quick swell) as the text lands, then folds.
- [ ] Force an error (e.g. turn Wi‑Fi off and dictate): the pill shudders sideways and settles, then shows the message.
- [ ] Press Esc mid-recording: the pill shrinks as it fades instead of only fading.
- [ ] With Reduce Motion on, none of the three moves; the colours and fades still happen.
- [ ] In the first-run gesture trainer, each press of your key makes the ring orb swell briefly; holding the key does not keep re-triggering it.
- [ ] The small orbs (settings sidebar, Overview header, finale menu bar) sit centred and look calm, not noisy.

### Deepgram Nova-3 provider (parley-012)

- [ ] Overview → Transcription key → Replace: the choice reads Whisper (Groq) / Deepgram Nova-3, with Groq selected on an existing install.
- [ ] Choose Deepgram Nova-3 with no Deepgram key: the title flips to Finish setup, the tray shows not ready, and a gesture is refused with “Add a Deepgram API key before trying the gesture.”
- [ ] Paste an invalid Deepgram key and Test and save: “Invalid API key”, nothing stored.
- [ ] Paste a real Deepgram key: “Key works”, the row says Stored, the title returns to Parley is ready.
- [ ] Dictate a sentence that uses a dictionary word (e.g. MiniMax): it pastes spelled as in the dictionary.
- [ ] Voice edit and Explain still work with Deepgram selected.
- [ ] Switch back to Whisper (Groq): dictation uses Groq again with no key re-entry.
- [ ] General → Custom vocabulary names Deepgram while it is selected, Whisper otherwise.

## Voice edit

Needs a MiniMax key saved on the Overview tab. The voice edit key defaults to Right
Command, with the same number of presses as dictation.

- [ ] Type a sentence into Notes, leave the cursor in it with nothing
      selected, hold the voice edit gesture and say "make it shorter". The
      whole note is replaced by a shorter version, and Cmd+Z brings the
      original back.
- [ ] Select one sentence of several and say "make it more formal": only the
      selection changes.
- [ ] Repeat the first check in Safari, Chrome, Slack and VS Code. Where the
      app hides the field's value the text visibly selects before it is
      replaced; that is the keystroke fallback, not a bug.
- [ ] With the Finder or a web page body focused (no text field), the orb
      shows "No text field focused" and nothing is selected or pasted.
- [ ] With the cursor in a password field, the orb shows "No text field
      focused".
- [ ] In an empty field the orb shows "Nothing to edit".
- [ ] The clipboard holds what it held before each of the checks above.
- [ ] With no MiniMax key, the voice edit gesture opens Settings on the
      MiniMax dialog and dictation still works.
- [ ] Setting the voice edit key to the dictation key turns voice edit off
      and the row says so.
- [ ] Voice edit works in the packaged build: `parley-ax` is inside
      `Parley.app/Contents/Resources`.

## Personal dictionary

The dictionary is `dictionary.json` in the app's userData folder. Until the
Dictionary tab exists, accepting an offer is the only way to add to it from
inside the app.

- [ ] In Notes, dictate a sentence of five or more words that contains a name
      Whisper gets wrong. Fix only that name by hand and stop typing. Within
      about five seconds the pill asks `Remember “Name”?` and names the
      dictation key.
- [ ] Tap the dictation key once: the pill turns teal with `Added “Name”`, and
      `dictionary.json` holds the name with the misspelling under `soundsLike`.
- [ ] Dictate the same sentence again: the name is pasted correctly.
- [ ] Let an offer pass twice for the same word: it is not offered a third
      time.
- [ ] With an offer showing, start a dictation with the usual gesture: the
      offer gives way to the waveform and nothing is added.
- [ ] With an offer showing, type a capital letter with Shift: nothing is
      added.
- [ ] Change an ordinary word (`today` to `tomorrow`), rewrite half the
      sentence, or add a sentence after it: no offer appears.
- [ ] Repeat the first check in Chrome and Slack. Where the app hides the
      field's value no offer appears; that is expected, not a bug.
- [ ] The offer never takes focus from the text field.

## Explain

Needs a MiniMax key (Settings, Overview). Default explain key is Right Control.

- [ ] Select a word in Notes, tap-tap-hold the explain key: the usual orb
      appears above the Dock (indigo) and listens. Say "why is this named that?"
      and release: the orb finishes, then a card fades in just below the
      selection, headed by your question, with a loading skeleton and then a short
      markdown answer to it. The selection stays highlighted and the text field
      keeps focus.
- [ ] A quick tap-tap-hold-release with no question gives a plain explanation.
- [ ] The answers are in English.
- [ ] Select a line of code with an unusual identifier (`useMemo`, `dedupeRecords`)
      and ask a question naming it out loud ("what does dedupeRecords do here?").
      The transcript spells it the way it is spelled in the code, not a
      phonetic guess.
- [ ] With the card still open, perform the gesture again and ask a follow-up
      ("what about the second point?"). A new turn appears below the first,
      marked as a reply, and the card scrolls to keep it in view — the first
      answer is not replaced. The answer takes the earlier turn into account.
- [ ] A third follow-up keeps growing the same thread past the 60% cap, and it
      scrolls; the earlier turns are still there above it.
- [ ] While the card is open, selecting different text and performing the
      gesture still follows up on the original selection, not the new one —
      dismiss the card first to explain the new selection instead.
- [ ] Esc, the X button, or a click outside closes the whole thread, not just
      the latest turn; the next gesture starts a new one.
- [ ] Select a recent product or obscure name and ask "what is this?": the answer
      takes a couple of seconds longer, uses current facts and ends with a site
      name in parentheses. Selecting a common word or code does not search.
- [ ] With Wi-Fi off, a failed search still ends in an answer or the usual error,
      never a stuck skeleton.
- [ ] Repeat in Safari, Chrome, VS Code and Terminal. Where the app hides its
      selection, the card appears beside the pointer instead.
- [ ] Select text at the bottom of the screen: the card flips above it. Select
      at the right edge: the card shifts left. Try a second display.
- [ ] A typical answer shows without a scrollbar. Select a whole paragraph of
      code: the card grows, and only scrolls past 60% of the screen height.
- [ ] The Copy icon puts the answer's markdown on the clipboard and shows a tick. Esc, the X button, or a click
      outside the card dismisses it; the card melts away rather than vanishing.
- [ ] The card reads as glass: the desktop blurs through it, over light and dark
      wallpapers, and its text stays legible. Its corners match the window's.
- [ ] Clicking Copy or X, and scrolling a long answer with the wheel, work without
      the text field losing focus.
- [ ] With nothing selected the card says "Select some text first" and goes away
      after two seconds.
- [ ] Selecting text in a password field shows nothing to explain, and the
      clipboard is untouched.
- [ ] With no MiniMax key the gesture opens Settings on the MiniMax dialog
      instead of a card.
- [ ] The clipboard holds what it held before each of the checks above.
- [ ] Setting the explain key to the dictation or voice edit key turns Explain
      off and the row says so.
