import { parseFocusedField, type FocusedField } from '../field-reader';
import type { Injector } from '../injector';
import type { TextRange } from '../terminal-input';
import type { ExplainContent, OrbPhasePayload, Rect, SessionBlockedReason } from '../types';
import type { Rpc } from './rpc';

/**
 * Everything the engine asks of the native shell, as typed calls over the
 * wire. The shell owns the OS: the pill, the keyboard and pasteboard, the
 * Accessibility tree, the explain popover, speech and login items. Each
 * method is one message; see ARCHITECTURE.md for the table.
 */
export interface Platform {
  orb: { show(): void; hide(): void; setPhase(payload: OrbPhasePayload): void };
  injector: Injector;
  /** The focused field through Accessibility; null when nothing answers. */
  readField(): Promise<FocusedField | null>;
  /** Moves the focused field's selection; false when the app would not. */
  selectRange(range: TextRange): Promise<boolean>;
  explainView: {
    show(anchor: Rect | null, content: ExplainContent): void;
    update(content: ExplainContent): void;
    hide(): void;
  };
  writeClipboard(text: string): void;
  speak(text: string): void;
  setLaunchAtLogin(enabled: boolean): void;
  openSettings(reason?: SessionBlockedReason): void;
  notify(method: string, params?: Record<string, unknown>): void;
}

/** How long the shell gets to answer an Accessibility read before it counts as "no field". */
const AX_TIMEOUT_MS = 2500;

export function createPlatform(rpc: Pick<Rpc, 'request' | 'notify'>): Platform {
  const notify = (method: string, params?: Record<string, unknown>) => rpc.notify(method, params);

  async function withTimeout<T>(promise: Promise<T>, fallback: T): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<T>((resolve) => {
      timer = setTimeout(() => resolve(fallback), AX_TIMEOUT_MS);
    });
    try {
      return await Promise.race([promise, timeout]);
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    orb: {
      show: () => notify('hud.show'),
      hide: () => notify('hud.hide'),
      setPhase: (payload) => notify('hud.phase', { ...payload }),
    },

    injector: {
      async paste(text, options = {}) {
        await rpc.request('paste.text', { text, selectAll: options.selectAll === true });
      },
      async copyAll() {
        const reply = await rpc.request<{ text?: unknown }>('inject.copyAll');
        return typeof reply?.text === 'string' ? reply.text : '';
      },
      async copySelection() {
        const reply = await rpc.request<{ text?: unknown }>('inject.copySelection');
        return typeof reply?.text === 'string' ? reply.text : '';
      },
      async erase(count) {
        if (count > 0) await rpc.request('inject.erase', { count });
      },
    },

    async readField() {
      try {
        const reply = await withTimeout(rpc.request('ax.focusedField'), null);
        // The shell answers in the same shape the old helper printed, so the
        // one parser (and its tests) still decide what counts as a field.
        return reply ? parseFocusedField(JSON.stringify(reply)) : null;
      } catch {
        return null;
      }
    },

    async selectRange(range) {
      try {
        const reply = await withTimeout(
          rpc.request<{ selected?: unknown }>('ax.select', { location: range.location, length: range.length }),
          null
        );
        return reply?.selected === true;
      } catch {
        return false;
      }
    },

    explainView: {
      show: (anchor, content) => notify('explain.show', { anchor, content }),
      update: (content) => notify('explain.update', { content }),
      hide: () => notify('explain.hide'),
    },

    writeClipboard: (text) => notify('clipboard.write', { text }),
    speak: (text) => notify('speak', { text }),
    setLaunchAtLogin: (enabled) => notify('app.launchAtLogin', { enabled }),
    openSettings: (reason) => notify('ui.openSettings', reason ? { reason } : undefined),
    notify,
  };
}
