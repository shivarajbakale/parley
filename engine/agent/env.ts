/**
 * The agent child's environment. The agent thinks with MiniMax, whose key
 * lives in parley-api: Mastra's `MINIMAX_BASE_URL` points the model at the
 * server's pass-through, which adds the real key, and `MINIMAX_API_KEY` is a
 * placeholder Mastra insists on (the server drops it). An explicitly exported
 * MINIMAX_API_KEY wins and talks to MiniMax directly: the environment is the
 * escape hatch. `PARLEY_SERVER_URL` gives the agent's web search the same
 * server. Packaged builds additionally run Electron-as-Node and say so,
 * so MCP stdio servers spawn without a system `node`.
 */

/** Sent in place of a key; parley-api never forwards it. */
export const SERVER_KEY_PLACEHOLDER = 'parley-server';
export function buildAgentEnv(deps: {
  processEnv: Record<string, string | undefined>;
  port: number;
  /** The Parley server address. */
  serverUrl: string;
  packaged: boolean;
  execPath: string;
}): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [key, value] of Object.entries(deps.processEnv)) {
    if (value !== undefined) env[key] = value;
  }
  env.PORT = String(deps.port);
  const server = deps.serverUrl.replace(/\/+$/, '');
  // The agent's web search asks the server too, which holds the Exa key.
  env.PARLEY_SERVER_URL = server;
  if (env.MINIMAX_API_KEY === undefined) {
    env.MINIMAX_API_KEY = SERVER_KEY_PLACEHOLDER;
    env.MINIMAX_BASE_URL = `${server}/api/providers/minimax/anthropic/v1`;
  }
  if (deps.packaged) {
    env.ELECTRON_RUN_AS_NODE = '1';
    env.PARLEY_NODE_BIN = deps.execPath;
  }
  return env;
}
