/**
 * Entry point of the headless engine: plain Node, no Electron. The native
 * shell spawns it and speaks newline-delimited JSON-RPC on stdin/stdout.
 *
 * stdout is the protocol and nothing else. Every console call is sent to
 * stderr before any engine module loads, so a stray log can never corrupt a
 * frame; the shell forwards stderr to its own log.
 */
import { spawn } from 'node:child_process';
import { readFile, rm } from 'node:fs/promises';
import { homedir } from 'node:os';
import path from 'node:path';
import { createInterface } from 'node:readline';

import { createCommonWords } from '../common-words';
import { createDictionaryStore } from '../dictionary-store';
import { createExplainClient } from '../explain-client';
import { createRewriter } from '../rewriter';
import { createSettingsStore } from '../settings-store';
import { createTranscriber } from '../transcriber';
import { createEngine } from './engine';
import { createRpc } from './rpc';
import { createKeyedCrypto } from './secret';

for (const level of ['log', 'info', 'warn', 'error', 'debug'] as const) {
  console[level] = (...args: unknown[]) => {
    process.stderr.write(`[engine:${level}] ${args.map(String).join(' ')}\n`);
  };
}

/**
 * Data lives where the Electron build kept it (named after the package), so
 * existing settings and dictionaries carry over. `PARLEY_DATA_DIR` overrides
 * it, for tests.
 */
const DATA_DIR =
  process.env.PARLEY_DATA_DIR ?? path.join(homedir(), 'Library', 'Application Support', 'parley');

/** The sync token's key arrives from the Keychain in `hello`. */
const crypto = createKeyedCrypto();
const store = createSettingsStore({ dir: DATA_DIR, crypto });
const dictionary = createDictionaryStore({ dir: DATA_DIR });
const serverUrl = () => store.get().syncUrl;
const transcriber = createTranscriber({ serverUrl, getProvider: () => store.get().transcriptionProvider });

let isCommon: ((word: string) => boolean) | null = null;
const isCommonWord = (word: string) => {
  try {
    isCommon ??= createCommonWords();
    return isCommon(word);
  } catch {
    // No system word list: every correction is worth offering.
    return false;
  }
};

const rpc = createRpc({
  write: (line) => process.stdout.write(line),
  onRequest: (method, params) => engine.onRequest(method, params),
  onNotify: (method, params) => engine.onNotify(method, params),
  onProtocolError: (message) => console.warn(message),
  // Voice edit and Act wait on the user (a paste, an Accessibility read of a
  // slow app); the shell answers within this or the call fails visibly.
  timeoutMs: 15_000,
});

const engine = createEngine({
  rpc,
  store,
  dictionary,
  transcriber,
  rewriter: createRewriter({ serverUrl }),
  explainClient: createExplainClient({ baseUrl: serverUrl }),
  crypto,
  isCommonWord,
  engineVersion: process.env.PARLEY_ENGINE_VERSION ?? 'dev',
  agentHost: {
    spawn: (command, args, opts) => {
      // argv, never a shell string.
      const child = spawn(command, args, { cwd: opts.cwd, env: opts.env, shell: false });
      return {
        on: (event, listener) => void child.on(event, listener),
        kill: (signal?: string) => void child.kill(signal as NodeJS.Signals),
        get exitCode() {
          return child.exitCode;
        },
        stdout: child.stdout,
        stderr: child.stderr,
      };
    },
    processEnv: process.env,
    execPath: process.execPath,
  },
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
  void engine.shutdown().finally(() => process.exit(0));
});

console.info(`engine ready, data dir ${DATA_DIR}`);
