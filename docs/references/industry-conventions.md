<!-- reference:industry-conventions:v1 -->

# Industry Design Conventions

Every app category has a visual language users already know. Knowing what it is
is the difference between a screen that feels at home and one that fights its
own category.

These are the conventions. Follow them by default — they exist because users
learned them, and breaking them costs a screen of trust the design has not yet
earned. When to break them: when the brand is the point (a fintech launch that
intentionally looks like a friend, a meditation app that intentionally looks
like a tool) and the *whole* design commits to the deviation. A single screen
that contradicts its category reads as a bug.

The kit covers most of what these conventions need without you asking — the
surface ladder, the typography scale, the motion vocabulary. The choice below
is *which* defaults the brand sits closest to, so you know what to keep and
what to override.

For the formal emotional-design half (Peak-End Rule, Spotify's three strategic
principles), see
[../principles/emotional-design.md](../principles/emotional-design.md). This
file is the *what kind of app is this* lookup; that file is the *how does the
user remember it* playbook.

---

## AI / Tech Products

Soft gradients, slow-moving elements, depth and dimensionality via glowing
edges. Dark *or* light themes with ethereal accent colours. Smooth animations
that read as "intelligent". Trust comes from motion that feels considered, not
from a particular palette.

Override the surface ladder toward more luminance steps if the brand leans on
glass — a glowing product wants more translucency in the chrome than a finance
app does. Motion: longer durations, slower shimmer, more spring.

## Crypto / Web3

Futuristic aesthetic: neon accents, bold typography, dark backgrounds,
geometric shapes, high-contrast cutting-edge visual language.

**Lesson from Phantom:** *polish builds trust*. Treat visual details, motion
and transitions as core product features, not as decoration to add later. A
crypto app that looks rough looks unsafe, and a crypto app that looks safe
looks like every other fintech. The work is in the micro-details — exact
shadows, consistent corner geometry, motion that finishes every frame — not in
the accent colour.

## Finance / Banking

Blue-dominant palettes (trust, stability, reliability). Generous white space,
clean layouts, conservative typography. The design must feel safe and
professional first.

**Lesson from Revolut:** *tactile interactions turn basic features into premium
experiences*. A draggable chart, a 3D card flip, a number that lands with a
spring — these are the differentiators. The bar is "looks like every other
bank", and the only way past it is interaction quality, not colour.

Override the type scale toward a more conservative face (a humanist sans, not
a geometric one). Motion: the most restrained of any category — small,
confident, never decorative. Sound and haptic on transaction completion is
*expected*, not optional.

## Health / Wellness

Bright, approachable colours that reduce anxiety. Friendly illustrations and
warm micro-interactions. Non-intimidating onboarding.

**Lesson from Ahead (Apple Design Award):** *guide users kindly, build the
peak as a personalised insight moment*. Health apps live and die on whether
the user trusts them with a daily ritual, and the trust is built one warm
micro-interaction at a time. The empty state is the relationship.

Override `DSEmptyState` toward illustration + warm copy for the *first* empty
state in a session; reserve the stark material glyph for the *recurring* one.
Motion: bouncy, generous, slower than other categories.

## Sleep / Meditation

Purple and deep blue tones (calming associations). Minimal UI, soft
transitions, ambient low-contrast interfaces.

Override the palette toward deep blue / violet surfaces in dark mode; in light
mode the brand colour belongs in the hero card, not in the chrome. Motion: the
slowest in the kit — fade and slow cross-dissolve only; never springs on
interactive elements. Reduce motion is on by default for this category.

## Education / Learning

Bright, playful palettes. Character-driven experiences with personality.

**Lesson from Duolingo:** *character animations + emotional feedback loops
doubled DAUs from 14.2M to 34M in two years*. Education is a retention
problem wearing an acquisition costume. The work is the daily loop's emotional
payoff, not the first session's onboarding.

The design system does not ship a character widget. If the app needs one, that
is a brand decision owned by `BLUEPRINT.md`, not a default. What the kit *does*
give you is the haptic + motion primitives a character animation layers on
top of. Build the character in `lib/screens/`, on top of the kit, with a
`DECISIONS.md` entry explaining the scope.

## Fitness

Energetic colours, bold typography, progress-focused with visual momentum
indicators (rings, bars, streaks).

The user's stage is the design variable. A new user needs motivation
(milestones, streaks, "first 7 days" framing); a returning user needs a
nudge (today's plan, what is at risk if they skip); a power user needs
information density (PRs, weekly trends, ratios). One UI for all three
fails the power user and patronises the new one.

The hierarchy below the hero changes by stage. What does not change: the
hero is the today's task, full stop. See
[../principles/emotional-design.md](../principles/emotional-design.md#peak-end-rule)
for why the streak itself is a peak, not a number.

## Productivity

Clean, minimal, information-dense but organised. Strong grid systems,
consistent spacing. Quick-action patterns (swipe, keyboard shortcuts).

The density tradeoff is the design variable. A new user wants the empty
calendar (low density, high confidence); a power user wants the week view
(high density, keyboard-driven). The default density is the one a power user
would tolerate, not the one a new user would prefer — because density can be
hidden with onboarding, but absence of density cannot be added later.

## E-commerce / Food

High-quality product photography. Prominent CTAs and frictionless checkout
flows. Trust signals: reviews, ratings, delivery estimates.

The peak is the moment the order is placed. Everything before that is
reducing friction to it; everything after is building the reason to come
back. See [../principles/emotional-design.md](../principles/emotional-design.md)
for the Peak-End mapping that drives the post-order moment.

Override the type scale toward a more display-friendly face for product
names. The card grid is the layout; the only design question is the image
ratio (square for catalog parity, 4:3 for editorial, 1:1 for fast scanning).

---

## How to use this file

1. In `BLUEPRINT.md`, name the app's category in the One-liner or as a
   section. If it does not fit any of the nine, name that explicitly.
2. The conventions here tell you what to *keep* from the kit defaults. Most
   apps do not override the surface ladder, the type scale, the motion
   vocabulary — they inherit them. The convention is the *brand colour choice
   inside the inherited system*.
3. When the brand deliberately contradicts the convention, the deviation
   goes in `DECISIONS.md` with a one-line reason ("crypto app that looks
   like a friend", "sleep app with a productivity aesthetic"). One-line,
   not a paragraph — the deviation is a flag, not a thesis.