import { createAudioWatchdog } from '../audio-watchdog';
import { applyReplacements, splitVocabulary, vocabularyTerms, whisperPrompt } from '../dictionary';
import type { DictionaryStore } from '../dictionary-store';
import { createGestureDetector } from '../gesture-detector';
import { createSession, type Session } from '../session';
import type { SettingsStore } from '../settings-store';
import type { Transcriber } from '../transcriber';
import {
  GESTURE_KEYS,
  type KeyEvent,
  type KeyName,
  type OrbPhasePayload,
  type PermissionStatus,
} from '../types';
import { PROTOCOL_VERSION, RPC_ERRORS, RpcError, type Rpc } from './rpc';

/**
 * The engine's composition root: the session, gesture detector, transcriber
 * and dictionary, with every OS side effect turned into a message to the
 * native shell in macos/.
 *
 * Phase 1 (parley-019) drives dictation only. Voice edit, Explain and Act keep
 * their engine paths, but the shell never starts them yet, so their deps here
 * refuse instead of half-working.
 */

/** How long `awaiting_audio` may wait for the shell's recording. */
export const AUDIO_WATCHDOG_MS = 5000;

const NOT_IN_THIS_BUILD = 'Not in the native build yet';

export interface EngineDeps {
  rpc: Pick<Rpc, 'request' | 'notify'>;
  store: Pick<SettingsStore, 'get' | 'recordDictation'>;
  dictionary: Pick<DictionaryStore, 'list' | 'recordUses'>;
  transcriber: Pick<Transcriber, 'transcribe'>;
  /** Reads the shell's temp recording, then removes it. */
  takeAudio(path: string): Promise<ArrayBuffer>;
  engineVersion: string;
}

export interface Engine {
  onRequest(method: string, params: Record<string, unknown> | undefined): Promise<unknown>;
  onNotify(method: string, params: Record<string, unknown> | undefined): void;
  /** For tests and diagnostics. */
  session: Session;
}

const KEY_NAMES = new Set<string>([...GESTURE_KEYS, 'Escape', 'Other']);

function parseKeyEvent(params: Record<string, unknown> | undefined): KeyEvent | null {
  if (!params) return null;
  const { type, key, time } = params;
  if (type !== 'down' && type !== 'up') return null;
  if (typeof time !== 'number' || !Number.isFinite(time)) return null;
  const name = typeof key === 'string' && KEY_NAMES.has(key) ? (key as KeyName) : 'Other';
  return { type, key: name, time };
}

function parsePermissions(value: unknown): PermissionStatus | null {
  if (!value || typeof value !== 'object') return null;
  const { microphone, accessibility } = value as Record<string, unknown>;
  if (typeof microphone !== 'boolean' || typeof accessibility !== 'boolean') return null;
  return { microphone, accessibility };
}

export function createEngine(deps: EngineDeps): Engine {
  const { rpc, store, dictionary } = deps;
  /** Nothing is granted until the shell says so in `hello`. */
  let permissions: PermissionStatus = { microphone: false, accessibility: false };

  // Declared ahead of its initializer: the watchdog closes over it, and only
  // fires after `createSession` below has run.
  // eslint-disable-next-line prefer-const
  let session: Session;

  /** A recording that never arrives must not wedge the session in `awaiting_audio`. */
  const audioWatchdog = createAudioWatchdog({
    timeoutMs: AUDIO_WATCHDOG_MS,
    onTimeout: () => {
      rpc.notify('log', { level: 'warn', message: 'no recording arrived; session recovered' });
      void session.receiveAudio({ data: new ArrayBuffer(0), mimeType: 'audio/mp4', durationMs: 0 });
    },
  });

  const orb = {
    show: () => rpc.notify('hud.show'),
    hide: () => rpc.notify('hud.hide'),
    setPhase: (payload: OrbPhasePayload) => {
      rpc.notify('hud.phase', { ...payload });
      // `transcribing` is set on entering `awaiting_audio`; any other phase
      // means the wait is over.
      if (payload.phase === 'transcribing') audioWatchdog.arm();
      else audioWatchdog.clear();
    },
  };

  session = createSession({
    orb,
    transcriber: deps.transcriber,
    injector: {
      paste: async (text) => {
        await rpc.request('paste.text', { text });
      },
    },
    rewriter: {
      rewrite: () => Promise.reject(new Error(NOT_IN_THIS_BUILD)),
    },
    editTargets: {
      capture: () => Promise.reject(new Error(NOT_IN_THIS_BUILD)),
      apply: () => Promise.reject(new Error(NOT_IN_THIS_BUILD)),
    },
    selection: { read: async () => null },
    explain: { ask: async () => {} },
    dictionary: {
      prompt: () => whisperPrompt(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      terms: () => vocabularyTerms(dictionary.list(), splitVocabulary(store.get().vocabulary)),
      apply: (text) => {
        const { text: fixed, hits } = applyReplacements(text, dictionary.list());
        dictionary.recordUses(hits);
        return fixed;
      },
    },
    getSettings: () => store.get(),
    runAgent: () => Promise.reject(new Error(NOT_IN_THIS_BUILD)),
    cancelAgent: () => {},
    isAgentReady: () => false,
    getPermissions: () => permissions,
    openSettings: () => rpc.notify('ui.openSettings'),
    onBlocked: (reason) => rpc.notify('session.blocked', { reason }),
    onDictation: (text) => store.recordDictation(text),
    onTranscript: (text) => rpc.notify('transcript', { text }),
  });

  const settings = store.get();
  const detector = createGestureDetector({
    key: settings.gestureKey,
    tapCount: settings.tapCount,
    onStart: () => session.start('dictate'),
    onStop: () => session.stop(),
    onCancel: () => session.cancel(),
  });

  async function receiveAudio(params: Record<string, unknown> | undefined) {
    const path = params?.path;
    const mimeType = params?.mimeType;
    const durationMs = params?.durationMs;
    if (typeof path !== 'string' || typeof mimeType !== 'string' || typeof durationMs !== 'number') {
      rpc.notify('log', { level: 'error', message: 'audio.ready with a malformed payload' });
      return;
    }
    let data: ArrayBuffer;
    try {
      // The shell answers every `transcribing` with an `audio.ready`; when
      // the recording failed or never started, the path is empty.
      data = path ? await deps.takeAudio(path) : new ArrayBuffer(0);
    } catch (error) {
      rpc.notify('log', {
        level: 'error',
        message: `could not read the recording: ${error instanceof Error ? error.message : String(error)}`,
      });
      data = new ArrayBuffer(0);
    }
    audioWatchdog.clear();
    await session.receiveAudio({
      data,
      mimeType,
      durationMs: data.byteLength === 0 ? 0 : durationMs,
    });
  }

  return {
    session,

    async onRequest(method, params) {
      if (method === 'hello') {
        if (params?.protocolVersion !== PROTOCOL_VERSION) {
          throw new RpcError(
            `Protocol mismatch: shell speaks ${String(params?.protocolVersion)}, engine speaks ${PROTOCOL_VERSION}`,
            RPC_ERRORS.invalidRequest
          );
        }
        const granted = parsePermissions(params.permissions);
        if (granted) permissions = granted;
        const current = store.get();
        return {
          protocolVersion: PROTOCOL_VERSION,
          engineVersion: deps.engineVersion,
          settings: {
            gestureKey: current.gestureKey,
            tapCount: current.tapCount,
            tickSound: current.tickSound,
            transcriptionProvider: current.transcriptionProvider,
            syncUrl: current.syncUrl,
          },
        };
      }
      throw new RpcError(`Unknown method ${method}`, RPC_ERRORS.methodNotFound);
    },

    onNotify(method, params) {
      switch (method) {
        case 'key': {
          const event = parseKeyEvent(params);
          if (!event) return;
          detector.handle(event);
          if (event.type === 'down' && event.key === 'Escape') session.cancel();
          return;
        }
        case 'audio.ready':
          void receiveAudio(params);
          return;
        case 'permissions.changed': {
          const granted = parsePermissions(params);
          if (granted) permissions = granted;
          return;
        }
        default:
          rpc.notify('log', { level: 'warn', message: `ignored notification ${method}` });
      }
    },
  };
}
