/**
 * The agent child's environment. The server thinks with the stored MiniMax
 * key, so Parley hands it over at spawn — no second setup step, no key in
 * a dotfile. An explicitly exported MINIMAX_API_KEY wins over the stored
 * one: the environment is the escape hatch. Packaged builds additionally
 * run Electron-as-Node and say so, so MCP stdio servers spawn without a
 * system `node`.
 *
 * Same-user local process, never logged: the key travels further than the
 * keychain but nowhere it can be read across the machine boundary.
 */
export function buildAgentEnv(deps: {
  processEnv: Record<string, string | undefined>;
  port: number;
  rewriteKey: string | null;
  packaged: boolean;
  execPath: string;
}): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [key, value] of Object.entries(deps.processEnv)) {
    if (value !== undefined) env[key] = value;
  }
  env.PORT = String(deps.port);
  if (env.MINIMAX_API_KEY === undefined && deps.rewriteKey) {
    env.MINIMAX_API_KEY = deps.rewriteKey;
  }
  if (deps.packaged) {
    env.ELECTRON_RUN_AS_NODE = '1';
    env.PARLEY_NODE_BIN = deps.execPath;
  }
  return env;
}
