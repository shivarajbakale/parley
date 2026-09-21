/**
 * Paste at the cursor by borrowing the clipboard: snapshot it, write the
 * transcript, send Cmd+V, then put the snapshot back. The restore runs in a
 * `finally`, so a failed paste never costs the user their clipboard.
 *
 * `copyAll` borrows it the other way, to read a field whose value the
 * Accessibility API would not give up.
 */

/** Let the pasteboard settle before the keystroke reads it. */
export const PASTE_SETTLE_MS = 50;
/** Let the target app read the pasteboard before it is restored. */
export const RESTORE_DELAY_MS = 200;
/** Let the target app act on Cmd+A before the next keystroke. */
export const SELECT_SETTLE_MS = 50;
/** Let the target app write the pasteboard after Cmd+C. */
export const COPY_SETTLE_MS = 150;

export interface InjectorDeps<Snapshot> {
  snapshot(): Snapshot;
  restore(snapshot: Snapshot): void;
  writeText(text: string): void;
  readText(): string;
  sendPaste(): void;
  sendCopy(): void;
  sendSelectAll(): void;
  delay?(ms: number): Promise<void>;
}

export interface Injector {
  /** `selectAll` replaces the whole focused field instead of the selection. */
  paste(text: string, options?: { selectAll?: boolean }): Promise<void>;
  /**
   * Select everything in the focused field and return it. Only safe once the
   * focus is known to be a text field: anywhere else Cmd+A selects the page.
   */
  copyAll(): Promise<string>;
  /** Copy whatever is selected right now and return it, without selecting anything. */
  copySelection(): Promise<string>;
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export function createInjector<Snapshot>(deps: InjectorDeps<Snapshot>): Injector {
  const delay = deps.delay ?? sleep;

  return {
    async paste(text, options = {}) {
      const saved = deps.snapshot();
      try {
        deps.writeText(text);
        await delay(PASTE_SETTLE_MS);
        if (options.selectAll) {
          deps.sendSelectAll();
          await delay(SELECT_SETTLE_MS);
        }
        deps.sendPaste();
        await delay(RESTORE_DELAY_MS);
      } finally {
        deps.restore(saved);
      }
    },

    async copyAll() {
      const saved = deps.snapshot();
      try {
        // Emptied first, so a Cmd+C that copies nothing reads back as nothing
        // rather than as whatever the user had copied earlier.
        deps.writeText('');
        deps.sendSelectAll();
        await delay(SELECT_SETTLE_MS);
        deps.sendCopy();
        await delay(COPY_SETTLE_MS);
        return deps.readText();
      } finally {
        deps.restore(saved);
      }
    },

    async copySelection() {
      const saved = deps.snapshot();
      try {
        deps.writeText('');
        deps.sendCopy();
        await delay(COPY_SETTLE_MS);
        return deps.readText();
      } finally {
        deps.restore(saved);
      }
    },
  };
}
