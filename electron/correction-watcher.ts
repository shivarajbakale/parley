import type { Correction } from './correction-detect';
import type { FieldReader } from './field-reader';

/**
 * After a dictation lands, look at the field a few times to see whether the
 * user fixes a word in it. The reads are the invisible Accessibility kind and
 * nothing is kept: the field is compared in memory and dropped.
 */

export const POLL_MS = 2000;
export const WATCH_MS = 30_000;

export interface CorrectionWatcher {
  /** Start watching the field `pasted` just went into. Replaces any earlier watch. */
  watch(pasted: string): void;
  cancel(): void;
}

export function createCorrectionWatcher(deps: {
  reader: FieldReader;
  detect(pasted: string, fieldValue: string): Correction | null;
  onCorrection(correction: Correction): void;
}): CorrectionWatcher {
  let timer: ReturnType<typeof setTimeout> | undefined;
  /** Bumped by every watch and cancel, so a read that resolves late is ignored. */
  let generation = 0;

  function cancel() {
    generation++;
    if (timer) clearTimeout(timer);
    timer = undefined;
  }

  return {
    cancel,

    watch(pasted) {
      cancel();
      const current = generation;
      const deadline = Date.now() + WATCH_MS;
      let lastSeen: Correction | null = null;

      async function poll() {
        const field = await deps.reader.read();
        if (current !== generation) return;
        // Focus left the field, or the app will not show its text: nothing to learn from.
        if (!field?.editable || !field.valueKnown) return;

        const found = deps.detect(pasted, field.value);
        // The same answer twice means the user has stopped typing the word.
        if (found && lastSeen?.word === found.word && lastSeen.heard === found.heard) {
          cancel();
          deps.onCorrection(found);
          return;
        }
        lastSeen = found;
        if (Date.now() + POLL_MS <= deadline) timer = setTimeout(poll, POLL_MS);
      }

      timer = setTimeout(poll, POLL_MS);
    },
  };
}
