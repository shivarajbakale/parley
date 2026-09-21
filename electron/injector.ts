/**
 * Paste at the cursor by borrowing the clipboard: snapshot it, write the
 * transcript, send Cmd+V, then put the snapshot back. The restore runs in a
 * `finally`, so a failed paste never costs the user their clipboard.
 */

/** Let the pasteboard settle before the keystroke reads it. */
export const PASTE_SETTLE_MS = 50;
/** Let the target app read the pasteboard before it is restored. */
export const RESTORE_DELAY_MS = 200;

export interface InjectorDeps<Snapshot> {
  snapshot(): Snapshot;
  restore(snapshot: Snapshot): void;
  writeText(text: string): void;
  sendPaste(): void;
  delay?(ms: number): Promise<void>;
}

export interface Injector {
  paste(text: string): Promise<void>;
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export function createInjector<Snapshot>(deps: InjectorDeps<Snapshot>): Injector {
  const delay = deps.delay ?? sleep;

  return {
    async paste(text) {
      const saved = deps.snapshot();
      try {
        deps.writeText(text);
        await delay(PASTE_SETTLE_MS);
        deps.sendPaste();
        await delay(RESTORE_DELAY_MS);
      } finally {
        deps.restore(saved);
      }
    },
  };
}
