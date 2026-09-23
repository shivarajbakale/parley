<!-- principle:screen-archetypes:v8 -->

# Screen Archetypes

Fifteen shapes. Every screen in a typical app is one of them, and saying which
one before you start is the difference between a layout and an arrangement.

## The failure this prevents

**Six identical tiles.** The current dashboard is a hero card followed by six
`1.9`-aspect icon tiles of equal weight — which is not a hierarchy, it is a
list wearing a grid's clothes. Nothing is the focal point, so the eye has
nowhere to land and the screen reads as filler.

Naming the archetype forces the question a grid lets you skip: *what is the one
thing on this screen?*

## Step 0 — name the category and the user stage, first

Picking an archetype without first naming the *kind of app* this is, and
*which user* this screen is for, gives you the right shape for the wrong
audience. Two questions, answered in `BLUEPRINT.md` or the feature's design
notes before any layout is drawn:

1. **Which industry conventions apply?** See
   [../references/industry-conventions.md](../references/industry-conventions.md).
   Finance, fitness, sleep, e-commerce and crypto each have a visual
   language users already know. A finance screen rendered as a sleep screen
   reads as wrong before the user can say why.
2. **Which user stage?** A new user, a returning user, and a power user
   want different things from the same screen. Density, copy and motion
   all change by stage. The fitness section of the conventions doc shows
   this most clearly.

Then name the peak moment on this screen (the moment the core task
completes) and the end moment (the last thing the user sees before
leaving). If you cannot name both, the screen does not yet have a shape —
just a layout. See
[emotional-design.md](emotional-design.md#peak-end-rule).

Only then pick the archetype below.

## Focal

**One hero at scale, then supporting content at unequal weights.**

For: a dashboard, a home screen, a "today" view — anywhere the user opens the
app to learn one thing.

- The hero is genuinely larger, not slightly larger. Two-thirds of the fold.
- Below it, a bento of **two sizes** — a wide one and a pair of narrow ones —
  so the grid has rhythm. Equal tiles have none.
- At most one gradient, on the hero (see
  [depth-and-materials.md](depth-and-materials.md)).
- Cap it. Six sections on a home screen means none of them mattered.

`DSStatTile`, `DSMetricBar`, `DSMessage`, `DSCard`.

## Collection

**Search, filter, refreshable list, swipe actions.**

For: any list of things the user browses.

- Search at the top (`DSSearchBar`, filtering the list in place).
- Filters as a horizontally scrolling chip strip — not a dropdown, which hides
  the current state.
- Pull-to-refresh always; a refresh button is a desktop idiom.
- Swipe for the destructive or common action (`DSDismissibleTile`), and the
  same action must also exist somewhere tappable — a swipe is not discoverable
  on its own.
- Rows: identity first, metadata second, one trailing control.
- Empty, zero-results and error are three different screens
  ([component-selection.md](component-selection.md)).

`DSListTile`, `DSSearchChip`, `DSEmptyState`. Rows are on screen at once — no
entrance cascade.
Pull-to-refresh is a `RefreshIndicator` around the list.

## Detail

**Collapsing large title, content, pinned action bar.**

For: the screen a Collection row opens.

- `DSLargeAppBar` — the title is the subject's name and collapses into the bar
  as it scrolls, which is where the platform difference is most visible.
- Content in titled sections (`DSContentSection`), not one wall of text.
- The primary action pins to the bottom over the content, on a chrome-layer
  surface, above the safe area. It must not scroll away.
- Secondary actions go in the app bar overflow (`DSMenu`), not in a row of
  five buttons.

## Form

**One column, one primary action, full width, above the safe area.**

For: sign-in, sign-up, create, edit, settings detail.

- One column. Always. Two-column forms are a desktop idiom that does not
  survive a 2× text scale.
- Label above the field, helper below, error replaces helper — so the layout
  does not jump when validation fires.
- The primary is **bottom, full width, above the safe area** — not bottom-right.
  That is the reachable zone on a phone, and it is the single clearest
  difference from the desktop pattern.
- Cancel is a ghost button or a route back, never a second filled button.
- Validate on submit first, then on blur once the user has submitted once.
- Disable the primary while submitting and show its loading state. Never
  allow a double submit.

`DSFormPage` is the shape — a fixed header, one scrolling column, the
primary in a `DSPinnedActionBar` below it — with `DSFormPage.hero` for the
entry point to a flow and `DSFormPage.fullBleed` for a form built from rows.
Inside it: `DSTextField`, `DSButton(isFullWidth: true)`, `DSSelect`,
`DSSwitch`.

## Settings

**Grouped inset lists, platform-correct controls.**

For: settings, preferences, account.

- `DSSettingsSection` — an eyebrow, a tinted rounded container of
  hairline-separated rows, an optional footer caption. That container is what
  makes a settings screen read as settings rather than as a list.
- Group by what the user is trying to change, not by which service owns it.
- The footer caption is where an explanation goes. A row with a paragraph
  under it is a row that will not survive a text-scale change.
- Destructive actions live in their own group at the bottom, with a confirm
  that names the object.
- A switch means the change applies immediately. If it needs a Save button, it
  was never a switch.

## Sequence

**One decision per screen, a step at a time, with a way back that costs
nothing.**

For: a first-run tour, a signup questionnaire, a booking flow, a setup wizard
— anywhere the user is walked rather than handed a page.

A Sequence is not a Form split across screens. A Form asks for a record; a
Sequence builds commitment, and the order is the design. Teardowns of the
flows that carry the most revenue converge on one rule worth stealing:

- **Every step names its job** — `brand`, `segmentation`, `trust`,
  `activation`, `monetization` or `retention`. A step that cannot name one is
  a step that exists because it was easy to build, and it is cut. This is the
  question a page count lets you skip.
- One decision per screen. Two questions is two steps.
- Progress is honest and lives at the top; the primary is pinned at the
  bottom. They never share the bottom edge — a progress bar and a keyboard
  fighting for the same 90 points is the defect this separation prevents.
- Back never destroys an answer. A user who steps back and forward again sees
  what they typed.
- The last step **hands over** — to Focal, or to Offer. A sequence that ends
  on itself is one the user leaves.
- Length is not the variable that matters. A three-stop tour and a thirty-step
  questionnaire are both correct if every step earns its job.

`DSTour`, `DSTourStop`, `DSTourDots`, `DSSegmentedProgress`, `DSStepper`,
`DSPinnedActionBar` for the pinned Next.

## Offer

**A named outcome, at most three plans, one action, and the price still
visible when the button is pinned over it.**

For: the paywall, the upgrade screen, the plan picker.

The vertical order is not a preference. It is what the screens that convert
have in common, and it goes:

1. The **outcome** in the user's terms — what they get, not what the tier is
   called.
2. The **trial timeline**, dated, when there is one. "Free" is not a timeline;
   "free until the 14th, then £39/year" is.
3. The **plans** — one, two or three. One removes the comparison, two
   separate flexibility from savings, and three need a reason you can say out
   loud. Four is a pricing page, not a paywall.
4. **Proof**, if there is any — a Free-versus-Pro table beats a scattered list
   of benefits.
5. The **primary**, naming the purchase. "Start 7-day free trial", not
   "Continue".
6. The **billing disclosure**, adjacent to that button: renewal amount, charge
   date, how to cancel, in plain language.
7. **Restore purchases, terms, privacy** — in the footer, reachable, never
   behind the primary.

Two rules the gates hold:

- **The pinned action must not cover the billing consequence.** A CTA sitting
  on a chrome surface over a scroll that runs beneath it will hide the
  renewal line at a 1.3× text scale, and the user finds out at the charge.
  `ui-probe`'s overlap ratchet is the gate.
- **Price, period and renewal stay adjacent to the selected plan** at every
  text scale. A savings badge with no baseline to compare against is not a
  saving.

Push it from the gated action, not from launch. A paywall that answers a
question the user was in the middle of asking outperforms one that greets
them.

`DSCard` for the plan rows, `DSPinnedActionBar`, `DSBadge` for the savings
flag, `DSButton(variant: ghost)` for restore.

## Insight

**One number, one picture, one sentence that says what the number means.**

For: the weekly recap, the report, the "how did I do" screen — anywhere the
app has been counting something and now has to hand the count back.

An Insight is not a Focal screen with a chart on it. A Focal screen asks the
user to do the next thing; an Insight asks them to *understand* something, and
the moment it grows a second subject it has become a dashboard, which is a
screen nobody reads twice. The order is fixed for the same reason the Offer's
is:

1. The **headline figure**, in the user's units — `4h 12m`, not `252`.
2. The **comparison** it is measured against, adjacent to it. A number with
   nothing to compare it to is trivia; the delta is the insight.
3. The **period** the figure covers, stated rather than implied. A figure
   whose denominator is a guess is a figure the user quietly distrusts.
4. **One chart**, showing the shape the headline is a summary of. One. Two
   plots on a recap is a dashboard.
5. **One sentence of interpretation**, in plain language, directly under the
   chart — "Tuesday carried the week." This is the part every analytics screen
   skips and the only part a person repeats to somebody else.
6. The **breakdown**, if there is one: the same total, split, ranked, with a
   bar per row so the ranking is visible before it is read.
7. A **handover** — the screen this recap leads to. An Insight that ends on
   itself is a screen the user closes.

Three rules the gates hold:

- **Nothing pins.** An Insight is read, not submitted. A pinned action bar
  over a recap steals the height the chart needs and implies a decision the
  screen is not asking for — the handover is an ordinary control at the end of
  the scroll.
- **The chart is never the only statement of its data.** A chart is silent to
  a screen reader and invisible in a screenshot description, so the headline,
  the sentence and the breakdown each carry the finding in text. `DSChart`
  derives a semantics label, and that is the floor, not the answer.
- **The comparison stays beside the figure at every text scale.** A delta that
  wraps onto its own line two paragraphs below the number it modifies is a
  second number.

`DSChart` for the plot, `DSStatTile` for the headline figure and its delta,
`DSMetricBar` for the breakdown rows, `DSSegmentedButton` when the period is
switchable, `DSSection` for the interpretation.

## Shelf

**One hero, then named horizontal rails of media tiles.**

For: a browse or discover screen — a streaming home, a store front, a podcast
directory. Anywhere the app has more content than the user has intent.

A Shelf is not a Collection. A Collection is one list the user *filters*; a
Shelf is many rails the app *ranked*, and the ranking is the product. Netflix
builds its home by ranking rows and then personalising the artwork inside them
([Artwork Personalization at Netflix](https://netflixtechblog.com/artwork-personalization-c589f074ad76)),
which is exactly why the rules below are about the row's title and the row's
honesty rather than about the picture.

- **Every rail names why it is here.** "Because you watched Poirot",
  "New this week", "Continue". A rail whose title is a genre nobody chose is a
  rail nobody asked for, and it is cut. This is the question a grid lets you
  skip.
- **A rail's end is reachable in three or four swipes.** Past that it stops
  being a rail and becomes a Collection route behind a "See all" — the control
  Spotify puts in every carousel's top-right corner. Nielsen Norman measured
  the same limit from the other side: sequential access is tedious, and users
  do not swipe a long carousel to its end
  ([Mobile Carousels](https://www.nngroup.com/articles/mobile-carousels/)).
- **The next tile peeks.** Partial visibility is the strong signifier for
  "this scrolls"; dots are weak ones. A rail whose last visible tile ends flush
  with the screen edge reads as a row that stops there.
- **Artwork is never the only statement of the title.** A personalised image is
  not a name — it is a guess about the viewer. The title is text under the
  tile, and `DSMediaSource` carries the picture's own text alternative so a
  reader who sees neither still gets both.
- **One hero, and it does not rotate on its own.** An auto-advancing hero moves
  the thing the user was about to tap.
- **At most one rail is the app talking about itself.** Promos are content
  competing with the content the user came for.

`DSMediaHero` for the hero, `DSMediaTile` at a token width for the rail items,
`DSSectionHeader` with a trailing "See all" for the rail title, `DSMediaRow`
when a rail is better read as a short vertical list (a "continue" strip of
three, say).

## Session

**A live running state: full bleed, one escape, no scroll.**

For: now-playing, a workout in progress, a timer, a recording, a call. The
screen the app is on while something is *happening*.

A Session is the only archetype whose subject changes while the user watches
it, and everything below follows from that.

- **Transport reads the playback state; it never keeps its own.** The button
  says pause because the player is playing. On Android the same state is what
  the system draws in Quick Settings and on the lock screen, derived from the
  media session rather than from your UI
  ([Android media controls](https://developer.android.com/media/implement/surfaces/mobile)),
  and two sources of truth is how a paused notification ends up over a playing
  screen.
- **The mini-player is the same session, not a second one.** Leaving the screen
  collapses it; it does not stop it. A route change that stops the audio is the
  bug this sentence exists to prevent.
- **Progress is a real target.** A one-point line is a decoration; the scrubber
  meets the kit's 44-point floor like every other control, and `ui-probe`'s
  `target` rule is the gate.
- **Elapsed and remaining are text.** A filled bar is silent to a screen reader
  and unreadable in a screenshot. `DSMediaStatus.duration` and `progress` speak
  themselves for the same reason.
- **Nothing pins, because nothing is submitted.** The transport *is* the
  chrome. A pinned action bar under a player is a second bottom edge.
- **One escape, and it is a down-chevron rather than a back arrow.** The
  session continues behind it; back implies it does not.
- **No scroll.** A session that scrolls has a Detail screen hidden inside it —
  the queue, the description, the notes — and that belongs in a sheet
  (`DSBottomSheet`), which is a Canvas, or on its own route.

`DSMediaSurface` for the stage, `DSMediaHero` when the art is the screen,
`DSSlider` for the scrubber, `DSIconButton` for transport, `DSMediaRow` for
the up-next queue inside the sheet.

## Canvas

**A spatial ground under a sheet with detents.**

For: a map, a floor plan, a photo the user pans, a seat picker — anywhere the
content is a *space* rather than a list, and the controls sit over it.

- **The ground stays interactive at every detent.** A sheet that blocks the map
  it is describing is a dialog wearing a sheet's shape. Material draws the same
  line between a standard sheet, which lives over content the user still
  touches, and a modal one, which does not
  ([Material 3 bottom sheets](https://m3.material.io/components/bottom-sheets/guidelines)).
- **The smallest detent leaves the subject visible.** Peek exists so the user
  can see the pin they just tapped; a peek that covers it has no reason to be
  a peek.
- **Two or three detents, named.** Peek, half, full. A sheet that settles
  anywhere is a sheet the user has to aim.
- **The handle is the affordance.** Drag is invisible without it, and the
  handle is also the tap target that cycles the detents.
- **Floating controls sit above the sheet's top edge, never under it.** A
  recentre button the sheet covers at half detent is a control that exists at
  one detent only.
- **The ground is never the only statement of the state.** A map is silent: the
  selected place's name, address and distance are text in the sheet.

`DSBottomSheet` with snap points for the sheet, `DSListTile` or `DSMediaRow`
for its rows, `DSIconButton` for the floating controls, `DSSection` for the
detail inside the sheet.

## Confirmation

**What happened, its identifier, what happens next, and a way onward.**

For: the end moment — order placed, booking made, transfer sent, upload
finished, account deleted.

The order is fixed, and it is the order the research keeps landing on: a
transaction confirmation's first job is confirming *this* transaction, and the
identifier is what makes it this one rather than a generic success page
([Baymard](https://baymard.com/blog/order-confirmation-page)). Nielsen Norman
found users hunt for the tracking number whether or not they ever use it — it
is the evidence that a real thing is on its way
([After the Buy Button](https://www.nngroup.com/articles/after-the-buy-button-in-e-commerce/)).

1. **What happened**, in the past tense and in the user's words. "Your order is
   placed", not "Success".
2. **The identifier**, selectable. An order number the user cannot copy is a
   number they photograph.
3. **A summary of the thing itself** — what was ordered, what was booked, how
   much was charged. This is the single most requested item on a confirmation.
4. **What happens next, dated.** "Arrives Thursday 12 March", not "soon". A
   confirmation with no next step is a receipt.
5. **The undo window, if there is one**, named here and nowhere else. "You can
   cancel until 6pm."
6. **One way onward** — track it, view it, done. A confirmation is the last
   screen of a flow, not the last screen of the app.

Two rules the gates hold:

- **A Confirmation is never a dialog.** The end moment of a flow that took four
  screens does not get dismissed by a tap outside it.
- **It says what it emailed.** "We sent a copy to ada@example.com" is what
  stops the user screenshotting the screen.

`DSMessage` for the outcome banner, `DSListTile` or `DSMediaRow` for the
summary rows, `DSSection` for what-happens-next, `DSPinnedActionBar` for the
way onward, `DSButton(variant: ghost)` for the secondary.

## Conversation

**A transcript that grows from the bottom, and the bar it is written in.**

For: chat, an assistant, support, a comment thread — anywhere the user's turn
is composed in place and answered.

It is the one shape where the network is visible to the user. A message exists
in the transcript before the server has it, and the gap between those two
facts is a state rather than a spinner over the screen. Nielsen Norman's work
on chatbots lands on the same point from the other side: the user's model of
the conversation is built from what they can see of its progress, and a turn
whose fate is reported somewhere else — a snackbar, a toast — is a turn they
believe was sent
([Chatbots](https://www.nngroup.com/articles/chatbots/)).

1. **The transcript is inverted.** The newest turn is at the bottom, and it
   stays there when the keyboard opens rather than sliding under it.
2. **Who spoke is drawn, not labelled.** The side, the fill and the tightened
   corner nearest the speaker do the work a name would.
3. **Every turn carries its state** — sending, streaming, sent, failed. A turn
   that did not send offers the retry in the transcript, where the user is
   already looking.
4. **The composer is the only pinned thing.** Its field grows to a ceiling and
   then scrolls itself; the bar keeps its bottom edge. Its send is dead until
   there is something to send, so nobody discovers that by tapping.
5. **The empty thread says what it is for.** A thread that opens blank has
   spent the one moment it had to say what to ask.

Two rules the gates hold:

- **A conversation pins nothing but the composer.** A bar under the composer
  is a second bottom edge, and the keyboard covers both.
- **One voice is not a conversation.** A transcript with a single speaker is a
  list, and it is planned as a Collection.

`DSChatBubble` for the turn, `DSComposer` for the bar, `DSEmptyState` for the
thread before its first turn.

## Editor

**The work fills the screen; the chrome is a bar over it.**

For: a document, a post, a long note, a drawing — anywhere the user makes
something they come back to.

It is not a Form. A form collects values the app needs and ends when they are
submitted; an editor holds work the user owns and never really ends. That
difference decides the layout: a form's primary is pinned because submitting
is the point, and an editor's bottom edge belongs to the toolbar because the
keyboard is up and the work is what the screen is for.

1. **One document.** A panel of controls beside the work has taken the room
   the work needed.
2. **The save state is on the screen, and true** — clean, saving, saved,
   conflict. "Saved" drawn while the write is in flight is the lie the user
   finds out about later, and `clean` draws nothing at all: a permanent
   "Saved" beside an untouched document is the label people stop reading
   before the one time it matters.
3. **Undo is one tap from where the mistake happened.** Never behind a menu —
   it is reached in a hurry, and hunting for it is what makes the mistake
   expensive.
4. **Say what saving means.** "Every keystroke, debounced two seconds", or "on
   Done". A save state nobody can predict is one nobody trusts.
5. **Leaving is answered here.** The platform back gesture will be used. What
   happens to unsaved work is the difference between a draft kept and a draft
   lost.

Two rules the gates hold:

- **An editor pins its toolbar, not a button.** The way out belongs in the
  header, where it is reachable without dismissing the keyboard.
- **A toggled tool gets its own glyph.** Colour alone carrying meaning fails
  WCAG SC 1.4.1, and an icon button has no label beside it to read instead.

## Schedule

**A day as a column of hours, with what is booked drawn on it.**

For: a calendar, a booking sheet, a rota, a room's availability.

The grid earns its height only when the question is *when* and the answer is
read from the day's shape — where the gaps are, what runs long, what collides.
When the question is *what*, an agenda of rows says the same thing in a fifth
of the space, and five things spread over ten hours is nine hours of ruled
paper.

1. **The day is named**, and another one is chosen from the strip above the
   grid rather than from a dialog.
2. **Two things at the same hour are side by side.** A booking hidden under
   another booking is the one that gets double-booked, and stacking is how a
   grid hides it.
3. **The window is a hint, not a crop.** A booking outside the opening hours
   widens the day. An event drawn nowhere is worse than a grid that scrolls
   further than it meant to.
4. **An empty day says so**, and says how to fill it.
5. **"Now" is drawn only for today** — and by the caller passing a time, not
   by the grid reading the clock, so the same day photographed twice is the
   same picture.
6. **The add action opens a Form, and the Form owns the recurrence.** A
   Schedule that cannot be added to is a picture of a calendar. What comes
   back is one booking with a rule on it, and the day asks the rule which of
   its own dates it falls on — the grid stores no copies, so moving or ending
   a series is one edit rather than fifty.
7. **A booking that repeats says so on the day.** The rule lives on the
   record, so the day is the only place a reader learns that today's 8:30 is
   every week's 8:30 — and a fifteen-minute slot has no room for the
   sentence, which is why `DSTimeSlot` draws a glyph when the words do not
   fit. The words stay in the semantics label either way.
8. **The rule gets its own screen once it has more than one control.** How
   often, every how many, on which days and until when is four controls; put
   under a name, a room, a day, a start and a length they run past the fold,
   where the probe does not measure and the golden does not photograph. The
   Form says the rule in words and opens the screen that writes it.

One rule the gates hold:

- **A slot never draws shorter than the tap-target floor.** A fifteen-minute
  booking at an honest scale is sixteen points tall: too small to hit, and too
  small to read.

`DSTimeGrid` for the day, `DSDateStrip` for choosing another, `DSEmptyState`
for the day with nothing on it.

## What is not an archetype

The splash screen is not one of the twelve and does not claim to be. It has no
content, no decision and no user — it is a launch state, and the moment it has
something to say it has become a Sequence's first step.

## Adding a sixteenth

Nothing is earmarked. Conversation, Editor and Schedule were the three shapes
the twelve could not describe, and each earned its place the way the four
before it did: `DSComposer` and `DSChatBubble` shipped first, then
`DSTimeGrid` (the editor's own bar has since been removed). The rules point at
them.

A new shape is a change to this document first, to `tool/feature_plan.dart`'s
and `tool/super_plan.dart`'s `archetypes` lists second, and to
`tool/superplan_lint.dart`'s required-kit table third. Each also needs its own
validation rules, its own wireframe body and its own tests — a shape a planning
tool cannot draw is a paragraph, not an archetype.

The bar for declaring one is not "this screen is different". It is: the shape
has rules a reviewer can fail a screen against, and it has kit behind those
rules. `Shelf` earned it when `DSMediaTile` shipped a carousel item; `Session`
when `DSMediaStatus` gave playback a typed state; `Canvas` from
`DSBottomSheet`'s snap points; `Confirmation` from `DSMessage` plus the pinned
bar; `Conversation` from `DSComposer` and `DSChatBubble`'s typed turn state.

## The demo screens

Every screen this project ships is one of the fifteen and says which in its
own doc comment. Not every archetype currently has a demo screen — Conversation
and Schedule do not — which is the state a fresh scaffold is in until a screen
claims them; the table below lists what exists, not the full fifteen.

| Screen | Archetype |
| --- | --- |
| `dashboard_page.dart` | Focal |
| `library_page.dart` | Collection |
| `library_detail_page.dart` | Detail |
| `login_page.dart`, `signup_page.dart` | Form |
| `settings_page.dart` | Settings |
| `welcome_page.dart`, `onboarding_page.dart`, `form_page.dart` | Sequence |
| `paywall_page.dart` | Offer |
| `insight_page.dart` | Insight |
| `browse_page.dart` | Shelf |
| `order_placed_page.dart` | Confirmation |
| `place_page.dart` | Canvas |

## The header earns its height

An expanded header (`DSLargeAppBar`) costs the first screenful a toolbar row
plus a measured title block — 162 of an 844-point screen on a pushed route.
It may only spend that on payload: a `subtitle`, an `eyebrow`, a `below` tab
strip, a `background`, or `actions`. A header that holds nothing but the
screen's name is a `DSCompactAppBar` (`DSPageHeader.compactSliver`) — one
navigation row, no collapse, chrome only once content is behind it.

`leading` is not payload. A back chevron or a drawer button is on almost every
screen, so counting it would make the rule vacuous — which is how three
top-level destinations came to spend a hundred points on a word the bottom nav
bar was already showing.

`below` is the tab-strip slot and is fixed at `component.tabHeight` (48). A
search field or a segmented control does not go there; it is content, and it
belongs in the scroll body.

The page has one headline. If a screen has a real headline, it goes in the
header's `title` (with a `subtitle` under it), not in a widget below a bar that
repeats the section's name — the blog list used to open on "Blog" above
"Rocketship Design Notes" and neither read as the page's name.

`ui_lint`'s `header-earns-its-height` rule is the gate.

## Choosing

| The screen is… | Archetype |
| --- | --- |
| the first thing after launch | Focal |
| ranked rails of things the app chose | Shelf |
| a list of things | Collection |
| one of those things | Detail |
| data the user types | Form |
| preferences | Settings |
| one of several steps, in an order you chose | Sequence |
| where the user is asked to pay | Offer |
| a number the app worked out, handed back | Insight |
| something happening right now | Session |
| a space with controls over it | Canvas |
| the end moment of a flow | Confirmation |
| turns the user writes and gets answered | Conversation |
| work the user makes and comes back to | Editor |
| when something happens, read off the day | Schedule |

A screen that is two archetypes is two screens. The usual case is a Detail
screen that grew a Collection inside it — that inner list belongs on its own
route, reached from a section header's "See all".

A Sequence step is the one exception worth stating: a step may be shaped like
a Form, but it is governed by the Sequence's rules — its job, its progress,
its handover — and it is planned as a Sequence.
