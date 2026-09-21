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

## Voice edit

Needs a MiniMax key saved in Setup. The voice edit key defaults to Right
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
- [ ] With no MiniMax key, the voice edit gesture opens Settings and
      dictation still works.
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

Needs a MiniMax key (Settings, Setup). Default explain key is Right Control.

- [ ] Select a word in Notes, tap-tap-hold the explain key: the usual orb
      appears above the Dock (indigo) and listens. Say "why is this named that?"
      and release: the orb finishes, then a card fades in just below the
      selection, headed by your question, with a loading skeleton and then a short
      markdown answer to it. The selection stays highlighted and the text field
      keeps focus.
- [ ] A quick tap-tap-hold-release with no question gives a plain explanation.
- [ ] The answers are in English.
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
- [ ] With no MiniMax key the card shows "No MiniMax key".
- [ ] The clipboard holds what it held before each of the checks above.
- [ ] Setting the explain key to the dictation or voice edit key turns Explain
      off and the row says so.
