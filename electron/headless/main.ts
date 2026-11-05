/**
 * Entry point of the headless engine: plain Node, no Electron. The native
 * shell spawns it and speaks newline-delimited JSON-RPC on stdin/stdout.
 *
 * stdout is the protocol and nothing else. Every console call is sent to
 * stderr before any engine module loads, so a stray log can never corrupt a
 * frame; the shell forwards stderr to its own log.
 */
import { readFile, rm } from 'node:fs/promises';
import { homedir } from 'node:os';
import path from 'node:path';
import { createInterface } from 'node:readline';

import { createDictionaryStore } from '../dictionary-store';
import { createSettingsStore, type CryptoLike } from '../settings-store';
import { createTranscriber } from '../transcriber';
import { createEngine } from './engine';
import { createRpc } from './rpc';

for (const level of ['log', 'info', 'warn', 'error', 'debug'] as const) {
  console[level] = (...args: unknown[]) => {
    process.stderr.write(`[engine:${level}] ${args.map(String).join(' ')}\n`);
  };
}

/**
 * The Electron build keeps its data under the package name, so both builds
 * read the same settings and dictionary. `PARLEY_DATA_DIR` overrides it, for
 * tests and for running the two side by side on purpose.
 */
const DATA_DIR =
  process.env.PARLEY_DATA_DIR ?? path.join(homedir(), 'Library', 'Application Support', 'parley');

/**
 * Electron's `safeStorage` is out of reach here. The only secret in settings
 * is the sync token, which dictation does not use: it reads as absent, and the
 * encrypted copy on disk is preserved untouched by every save.
 */
const noCrypto: CryptoLike = {
  isEncryptionAvailable: () => false,
  encryptString: () => {
    throw new Error('Encryption is not available in the native build yet');
  },
  decryptString: () => {
    throw new Error('Encryption is not available in the native build yet');
  },
};

const store = createSettingsStore({ dir: DATA_DIR, crypto: noCrypto });
const dictionary = createDictionaryStore({ dir: DATA_DIR });
const transcriber = createTranscriber({
  serverUrl: () => store.get().syncUrl,
  getProvider: () => store.get().transcriptionProvider,
});

const rpc = createRpc({
  write: (line) => process.stdout.write(line),
  onRequest: (method, params) => engine.onRequest(method, params),
  onNotify: (method, params) => engine.onNotify(method, params),
  onProtocolError: (message) => console.warn(message),
});

const engine = createEngine({
  rpc,
  store,
  dictionary,
  transcriber,
  engineVersion: process.env.PARLEY_ENGINE_VERSION ?? 'dev',
  takeAudio: async (file) => {
    try {
      const buffer = await readFile(file);
      return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
    } finally {
      await rm(file, { force: true });
    }
  },
});

const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
lines.on('line', (line) => rpc.receive(line));
// The shell closing the pipe is the only shutdown signal the engine needs.
lines.on('close', () => {
  rpc.close('shell closed the pipe');
  process.exit(0);
});

console.info(`engine ready, data dir ${DATA_DIR}`);
