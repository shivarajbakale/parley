import type { AgentMcpServer } from '../types';

/**
 * The Mastra server's keeper. On launch it attaches to a port that already
 * answers; otherwise it spawns the child (when managed) and polls it healthy.
 * A failure to start fails fast and names itself — only a crash after
 * healthy earns restarts, three of them, and a steady minute forgives.
 *
 * Everything the OS touches arrives through deps, so the whole lifecycle is
 * a unit test with a fake child.
 */

export interface SupervisorOutput {
  on(event: 'data', listener: (chunk: unknown) => void): void;
}

export interface SupervisorChild {
  on(event: 'error' | 'exit', listener: (...args: unknown[]) => void): void;
  kill(signal?: string): void;
  readonly exitCode: number | null;
  readonly stdout: SupervisorOutput | null;
  readonly stderr: SupervisorOutput | null;
}

export interface SpawnSpec {
  command: string;
  args: string[];
  cwd: string;
  env: Record<string, string>;
  /** Human words for failure messages: what was Parley trying to start. */
  description: string;
}

export interface SupervisorConfig {
  autoStart: boolean;
  /** False for a remote URL: attach-only, Parley never spawns there. */
  managed: boolean;
  spawn: SpawnSpec;
  port: number;
  pollMs?: number;
  readyTimeoutMs?: number;
  backoffMs?: number[];
  killGraceMs?: number;
  steadyMs?: number;
}

export interface SupervisorStatus {
  state: 'starting' | 'online' | 'offline';
  managed: boolean;
  message: string;
  /** The current restart number, for "Starting… (retry N of 3)". */
  attempt: number;
  mcpServers: AgentMcpServer[];
}

export interface HealthReading {
  ok: boolean;
  message: string;
  mcpServers: AgentMcpServer[];
}

export interface AgentSupervisor {
  start(): void;
  stop(): void;
  restart(): void;
  refresh(): Promise<{
    online: boolean;
    managed: boolean;
    serverState: SupervisorStatus['state'];
    message: string;
    mcpServers: AgentMcpServer[];
  }>;
  status(): SupervisorStatus;
}

const POLL_MS = 1000;
const READY_TIMEOUT_MS = 30_000;
const BACKOFF_MS = [1000, 2000, 4000];
const KILL_GRACE_MS = 2000;
const STEADY_MS = 60_000;

export function createSupervisor(deps: {
  getConfig(): SupervisorConfig;
  spawn(command: string, args: string[], opts: { cwd: string; env: Record<string, string> }): SupervisorChild;
  checkHealth(): Promise<HealthReading>;
  onLog?(line: string): void;
}): AgentSupervisor {
  let state: SupervisorStatus['state'] = 'offline';
  let managed = false;
  let message = '';
  let attempt = 0;
  let restartsUsed = 0;
  let mcpServers: AgentMcpServer[] = [];
  let child: SupervisorChild | null = null;
  let generation = 0;
  let timers: ReturnType<typeof setTimeout>[] = [];
  /** The last stderr lines, for naming whatever killed the child. */
  let errors: string[] = [];

  function later(ms: number, run: () => void): void {
    const mine = generation;
    const timer = setTimeout(() => {
      timers = timers.filter(other => other !== timer);
      if (mine === generation) run();
    }, ms);
    timers.push(timer);
  }

  function clearTimers(): void {
    for (const timer of timers) clearTimeout(timer);
    timers = [];
  }

  function log(line: string): void {
    deps.onLog?.(line);
  }

  function killChild(): void {
    const target = child;
    child = null;
    if (!target || target.exitCode !== null) return;
    target.kill('SIGTERM');
    later(deps.getConfig().killGraceMs ?? KILL_GRACE_MS, () => {
      if (target.exitCode === null) target.kill('SIGKILL');
    });
  }

  function snapshot(): SupervisorStatus {
    return { state, managed, message, attempt, mcpServers };
  }

  function fail(text: string): void {
    killChild();
    state = 'offline';
    message = text;
  }

  /** A child that dies on its own is either a stillborn spawn or a crash. */
  function onChildExit(code: unknown): void {
    if (!child || state === 'offline') return;
    child = null;
    const lastLine = errors.length ? errors[errors.length - 1] : `exit ${String(code)}`;
    if (state !== 'online') {
      // Never healthy: a failed start, not a crash. Fail fast and name it.
      state = 'offline';
      message = /EADDRINUSE/.test(errors.join('\n'))
        ? `port busy — something else holds :${deps.getConfig().port}`
        : `server failed to start — ${lastLine}`;
      return;
    }
    const backoff = deps.getConfig().backoffMs ?? BACKOFF_MS;
    if (restartsUsed >= backoff.length) {
      state = 'offline';
      message = `Server keeps crashing — ${lastLine}`;
      return;
    }
    const wait = backoff[restartsUsed];
    restartsUsed += 1;
    attempt = restartsUsed;
    state = 'starting';
    message = '';
    later(wait, () => {
      if (state !== 'starting') return;
      spawnAndWait();
    });
  }

  function watchStreams(target: SupervisorChild): void {
    const onLine = (line: unknown, isError: boolean) => {
      const text = String(line).trim();
      if (!text) return;
      log(text);
      if (!isError) return;
      errors = [...errors.slice(-4), text];
    };
    target.stdout?.on('data', chunk => onLine(chunk, false));
    target.stderr?.on('data', chunk => onLine(chunk, true));
  }

  function spawnAndWait(): void {
    const cfg = deps.getConfig();
    const pollMs = cfg.pollMs ?? POLL_MS;
    const readyTimeoutMs = cfg.readyTimeoutMs ?? READY_TIMEOUT_MS;
    let target: SupervisorChild;
    try {
      target = deps.spawn(cfg.spawn.command, cfg.spawn.args, {
        cwd: cfg.spawn.cwd,
        env: cfg.spawn.env,
      });
    } catch (error) {
      const code = (error as { code?: unknown })?.code;
      fail(`Could not start ${cfg.spawn.description} (${String(code ?? 'spawn failed')})`);
      return;
    }
    child = target;
    managed = true;
    state = 'starting';
    message = '';
    errors = [];
    watchStreams(target);
    target.on('error', () => {
      // The exit event carries the verdict; this only stops an unhandled error.
    });
    target.on('exit', code => {
      if (target === child) onChildExit(code);
    });

    const started = Date.now();
    const steadyMs = cfg.steadyMs ?? STEADY_MS;
    const poll = async (): Promise<void> => {
      if (target !== child || state !== 'starting') return;
      let health: HealthReading;
      try {
        health = await deps.checkHealth();
      } catch {
        health = { ok: false, message: 'health check failed', mcpServers: [] };
      }
      if (target !== child || state !== 'starting') return;
      if (health.ok) {
        state = 'online';
        message = '';
        mcpServers = health.mcpServers;
        later(steadyMs, () => {
          if (target === child && state === 'online') {
            restartsUsed = 0;
            attempt = 0;
          }
        });
        return;
      }
      if (Date.now() - started >= readyTimeoutMs) {
        fail('Server did not answer in time');
        return;
      }
      later(pollMs, () => void poll());
    };
    void poll();
  }

  return {
    start() {
      if (state !== 'offline') return;
      state = 'starting';
      message = '';
      void (async () => {
        const mine = generation;
        let health: HealthReading;
        try {
          health = await deps.checkHealth();
        } catch {
          health = { ok: false, message: 'health check failed', mcpServers: [] };
        }
        if (mine !== generation || state !== 'starting') return;
        if (health.ok) {
          // Someone — the user's own `mastra dev`, a second Parley — is
          // already serving. Attach; never double-spawn.
          state = 'online';
          managed = false;
          mcpServers = health.mcpServers;
          return;
        }
        const cfg = deps.getConfig();
        if (!cfg.autoStart) {
          state = 'offline';
          message = 'Auto-start is off — start the server yourself';
          return;
        }
        if (!cfg.managed) {
          state = 'offline';
          message = health.message;
          return;
        }
        spawnAndWait();
      })().catch(() => {
        // Every path above settles state; this only stops an unhandled rejection.
      });
    },

    stop() {
      generation += 1;
      clearTimers();
      killChild();
      state = 'offline';
      managed = false;
      message = '';
      attempt = 0;
      restartsUsed = 0;
      mcpServers = [];
    },

    restart() {
      // Restart only manages what Parley spawned; main disables the button
      // while attached. A stray call just re-checks the stranger's health.
      if (!managed && state === 'online') {
        void this.refresh();
        return;
      }
      this.stop();
      this.start();
    },

    async refresh() {
      let health: HealthReading;
      try {
        health = await deps.checkHealth();
      } catch {
        health = { ok: false, message: 'health check failed', mcpServers: [] };
      }
      mcpServers = health.mcpServers;
      if (!child) {
        // Nobody to watch: the reading IS the state.
        state = health.ok ? 'online' : 'offline';
        if (!health.ok) message = health.message;
        else message = '';
      } else if (!health.ok) {
        message = health.message;
      }
      return {
        online: state === 'online',
        managed,
        serverState: state,
        message,
        mcpServers,
      };
    },

    status: snapshot,
  };
}
