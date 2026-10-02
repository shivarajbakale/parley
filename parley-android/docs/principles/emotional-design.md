<!-- principle:emotional-design:v1 -->

# Emotional Design

A screen passes every visual gate and still feels flat. The spacing is right,
the type is right, the shadow is right, and the user closes the app without
remembering it.

That is the failure this principle exists to prevent. The other principles in
this folder own the *pixels*. This one owns the *moment the user takes away*.

---

## Peak-End Rule

From the Nobel-Prize-winning research of Daniel Kahneman: the brain does not
remember an experience as a whole. It compresses the experience into two
moments — the **peak** (the most intense moment) and the **end** (the final
impression before leaving). Disney parks use this deliberately: 70% of
visitors return not because the whole day was flawless, but because the
moments they remember were.

The corollary for app design is uncomfortable: **a screen that is uniformly
good is less remembered than a screen that is mostly quiet with one excellent
moment and one excellent ending.** Spending polish evenly across a screen
dilutes it; concentrating polish at the peak and the end multiplies it.

### Mapping the flow

Before designing any screen with a memorable moment, map the flow:

1. Lay out every step in the core task (FigJam, sticky notes, a list — the
   medium does not matter).
2. For each step, ask: where is the user slowed down? Where might stress
   peak? Where is the quiet?
3. Treat the map as a living document. It changes as the design does.

The output is not a wireframe. It is a *feeling map* — knowing which steps
are peaks (and need design attention) and which are commute (and should be
quiet).

### Designing the peak

Pick **one** spot to create the "holy dang" moment. After completing the
core task. After the number lands. After the thing the user came for
appears. That is the peak, and it earns:

- a spring or a haptic, not a curve (`docs/principles/motion.md` — the
  haptic/sync primitives are in `app_haptics.dart` and `app_motion.dart`)
- the accent colour at full saturation, not 5% (`docs/principles/depth-and-materials.md`)
- a moment of stillness after the motion — the eye needs the motion to
  *finish*, not loop

A second peak is a tie, and ties forgettable. The rule is one peak, and the
rest of the screen stays quiet. Motion on a row that does nothing reads as
lag.

### Designing the end

The last thing on screen before the user leaves. The end earns:

- a summary, not a wall of data ("Your streak: 12 days" beats "Activity: 12
  days, 3.2 hours, 47 sessions")
- a reason to come back, not a CTA that requires a tap ("See you tomorrow"
  beats "Browse more")
- a still image, not a moving one — the end is where the eye rests, and
  resting means no shimmer, no cascade, no spring settling

The end is not the place to be clever. The end is the place to be
*unforgettable for being simple*.

---

## Spotify's three strategic principles

These are not "best practices". They are product decisions that drive
specific design moves.

### 1. The Trojan Horse — hide complex tech in familiar interfaces

Wrap sophisticated features in UI patterns users already know. Users do not
want to interact with algorithms — they want experiences that feel natural.

The implementation question is: *what is the simplest, most familiar way the
user can interact with this feature?* A recommendation engine becomes a
"For You" tab. A model selector becomes a slider with three named
presets. An analytics dashboard becomes a daily summary.

The trap: "but the user needs to see the underlying data". They do not. They
need to act on it. Exposing the mechanism is a Trojan Horse that failed —
the horse is showing through.

### 2. The Vanity Mirror — make sharing about identity, not the app

Create personal insights so meaningful that sharing feels like
self-expression.

> "You're a night owl who does your best work after 9 PM"
>
> is shared more than
>
> "You completed 25 tasks"

The first celebrates *who the user is*. The second celebrates *what the app
tracked*. People share identity; they do not share app screenshots.

The implementation question is: *what is true about this user that they did
not know before they opened the app?* That is the insight worth sharing. A
generic "you completed X" notification is not it.

### 3. The Comfort Trap — consistency is the moat

Spotify's interface barely changes year over year. That is not stagnation —
it is a moat. The user's hands know where things are. The user's eye knows
where to look. Every redesign costs the user the work they already did.

The implementation question is: *is this change worth the user re-learning?*
If the answer is yes, change it. If the answer is "it would look nicer", do
not. The kit's design discipline
([component-selection.md](component-selection.md),
[depth-and-materials.md](depth-and-materials.md),
[motion.md](motion.md)) exists for the same reason: predictability is a
feature.

---

## Emotional feedback loops

The smallest unit of emotional design is the feedback loop — the user does
a thing, the app responds, the user knows the response was for *them*. Three
layers:

| Layer | Owner | Failure mode |
| --- | --- | --- |
| **Instant** (under 100ms) | The press itself | A button that does not press is a button that might not work |
| **Local** (100–500ms) | The state change in place | A toggle without a visible state change is a guess the user has to make |
| **Outcome** (over 500ms) | The completion moment | An action that ends silently feels like nothing happened |

The kit owns the first two — `DSPressable` owns instant, every stateful
component owns local. The third is the Peak-End peak. See
[premium.md](premium.md) for the "celebratory feedback on success" line.

---

## What this principle is not

This is not "add delight everywhere". Delight added to a row that does
nothing is decoration, and decoration at scale is the first thing users
filter out. The whole point of the peak-end rule is that **most of the
screen should be quiet** so the peak and the end are loud by contrast.

This is also not "be emotional instead of useful". Emotional design without
utility is a sticker on a broken product. The kit's
[component-selection.md](component-selection.md),
[depth-and-materials.md](depth-and-materials.md) and
[spacing-and-type.md](spacing-and-type.md) own the useful half. This
principle owns what the user takes away from it.

---

## How this app encodes it

| The principle | Where it lives in this app |
| --- | --- |
| The peak | `design-pass` Step 3 — "Find the peak". This principle file is the *why*; the skill is the *how*. |
| The end | The empty state of a list with content completed; the success snack bar; the onboarding "see you tomorrow" panel. |
| Trojan Horse | `DSSelect` (a dropdown wearing a button), `DSSegmentedButton` (a model selector wearing tabs). |
| Vanity Mirror | Not encoded as a default — this is a brand decision that lives in `BLUEPRINT.md`. |
| Comfort Trap | The kit's stability itself. Don't redesign what is working. |
| Emotional feedback loops | `DSPressable` (instant) + every stateful component (local) + the peak (outcome). |

The cross-references are deliberate: this principle does not duplicate the
visual rules. It tells you *when* to spend them, and when not to.