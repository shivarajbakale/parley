/**
 * The only animation values in the app. Every `motion` component reads these,
 * so the whole product moves with one character.
 */
export const SPRING = { type: 'spring', stiffness: 380, damping: 30 } as const;

/** Decelerating curve for opacity and colour, where a spring would overshoot. */
export const EASE = [0.22, 1, 0.36, 1] as const;

/** Seconds, because that is what `motion` takes. */
export const DURATION = { fast: 0.15, base: 0.25, slow: 0.4 } as const;

/** Delay between siblings in a staggered entrance, in seconds. */
export const STAGGER = 0.04;
