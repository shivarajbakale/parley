import type { SessionMode } from '../../electron/types';

/**
 * Parley's three sounds, synthesized so no audio asset ships: a rising glass
 * pair when it starts listening, the same pair falling when it stops, and the
 * two notes together when the text lands.
 *
 * Each note is a sine with a quiet octave partial and a long exponential tail,
 * which is what makes a plain oscillator read as struck glass. The start sound
 * is the quietest and shortest of the three because the microphone is already
 * opening while it plays.
 */

/** A perfect fifth: E5 up to B5. */
const LOW_HZ = 659.26;
const HIGH_HZ = 987.77;
/** Voice edit speaks a major third higher, with a detuned double for shimmer. */
const EDIT_RATIO = 1.26;
const SHIMMER_CENTS = 9;

interface Note {
  hz: number;
  /** Seconds after the sound begins. */
  at: number;
  peak: number;
  decay: number;
}

export type SoundName = 'start' | 'stop' | 'done';

export function notesFor(sound: SoundName): Note[] {
  switch (sound) {
    case 'start':
      return [
        { hz: LOW_HZ, at: 0, peak: 0.05, decay: 0.16 },
        { hz: HIGH_HZ, at: 0.07, peak: 0.06, decay: 0.2 },
      ];
    case 'stop':
      return [
        { hz: HIGH_HZ, at: 0, peak: 0.09, decay: 0.22 },
        { hz: LOW_HZ, at: 0.08, peak: 0.1, decay: 0.32 },
      ];
    case 'done':
      return [
        { hz: LOW_HZ, at: 0, peak: 0.07, decay: 0.45 },
        { hz: HIGH_HZ, at: 0, peak: 0.06, decay: 0.45 },
        { hz: LOW_HZ * 2, at: 0.02, peak: 0.03, decay: 0.5 },
      ];
  }
}

let shared: AudioContext | null = null;

/** One context for the orb's lifetime: a fresh one per sound adds audible latency. */
function audio(): AudioContext {
  if (!shared || shared.state === 'closed') shared = new AudioContext();
  if (shared.state === 'suspended') void shared.resume();
  return shared;
}

function strike(context: AudioContext, note: Note, detuneCents: number, level: number) {
  const start = context.currentTime + note.at;
  const gain = context.createGain();
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(note.peak * level, start + 0.004);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + note.decay);
  gain.connect(context.destination);

  // The fundamental, and an octave partial at a fifth of its level.
  for (const [multiple, share] of [
    [1, 1],
    [2, 0.2],
  ]) {
    const oscillator = context.createOscillator();
    const partial = context.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.value = note.hz * multiple;
    oscillator.detune.value = detuneCents;
    partial.gain.value = share;
    oscillator.connect(partial).connect(gain);
    oscillator.start(start);
    oscillator.stop(start + note.decay + 0.02);
  }
}

export function playSound(sound: SoundName, mode: SessionMode = 'dictate') {
  const context = audio();
  for (const note of notesFor(sound)) {
    if (mode === 'edit') {
      const raised = { ...note, hz: note.hz * EDIT_RATIO };
      strike(context, raised, -SHIMMER_CENTS, 0.6);
      strike(context, raised, SHIMMER_CENTS, 0.6);
    } else {
      strike(context, note, 0, 1);
    }
  }
}
