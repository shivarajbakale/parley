import type { Agent } from '@mastra/core/agent';
import { Mastra } from '@mastra/core/mastra';

import { createParleyAgent } from './agents/parley-action';
import { createMcpClient, listCatalog, loadServerDefinitions } from './parley/mcp';
import { createRunStore } from './parley/runs';
import { createParleyRoutes } from './parley/routes';
import { createWebSearchTool, WEB_SEARCH_CATALOG, WEB_SEARCH_TOOL } from './parley/web-search';

/**
 * Parley's agent server. One agent, `parley-action`, works voice commands
 * through the configured MCP servers; six `/parley/*` routes carry runs,
 * approvals and health back to the desktop app.
 *
 * The model is `PARLEY_MODEL` (a Mastra `provider/id` string, default
 * MiniMax-M3 — the same model and key Parley's voice edit uses, handed
 * over by the desktop app at spawn) or `mock:<read|write|plain|notes>`
 * for keyless end-to-end verification — see `parley/mock.ts`.
 */

const MODEL_FALLBACK = 'minimax/MiniMax-M3';

type AgentModel = ConstructorParameters<typeof Agent>[0]['model'];

async function resolveModel(): Promise<AgentModel> {
  const raw = (process.env.PARLEY_MODEL ?? MODEL_FALLBACK).trim() || MODEL_FALLBACK;
  if (raw.startsWith('mock:')) {
    // Lazy: the mock pulls the Mastra test utils (and vitest) which a real
    // model must never load.
    const { createMockModel, isMockScenario } = await import('./parley/mock.js');
    const scenario = raw.slice('mock:'.length);
    if (!isMockScenario(scenario)) throw new Error(`unknown mock model "${raw}"`);
    return createMockModel(scenario);
  }
  return raw;
}

const definitions = await loadServerDefinitions();
const mcp = createMcpClient(definitions);
const tools = await mcp.listTools().catch(error => {
  throw new Error(`MCP discovery failed: ${(error as Error).message}`);
});
// Web search needs the Parley server, which holds the Exa key; without an
// address (smoke runs, a bare `mastra dev`) the agent has MCP tools only.
const serverUrl = process.env.PARLEY_SERVER_URL?.trim();
const builtins: Record<string, ReturnType<typeof createWebSearchTool>> = serverUrl
  ? { [WEB_SEARCH_TOOL]: createWebSearchTool(serverUrl) }
  : {};
const descriptions = new Map<string, string>();
for (const [name, tool] of Object.entries(tools)) {
  const description = (tool as { description?: unknown }).description;
  if (typeof description === 'string' && description) descriptions.set(name, description);
}

const agent = createParleyAgent({ model: await resolveModel(), tools: { ...builtins, ...tools } });
const store = createRunStore(agent, descriptions);

const catalog = [...(serverUrl ? [WEB_SEARCH_CATALOG] : []), ...(await listCatalog(mcp).catch(() => []))];
console.log(
  `[parley] serving ${Object.keys(tools).length + Object.keys(builtins).length} tools from ${catalog.map(entry => entry.name).join(', ') || 'no servers'}`
);

export const mastra = new Mastra({
  // NOTE: `bundler.externals: false` (one self-contained bundle, no
  // node_modules) fails on mastra 1.30: Rollup chokes inside @mastra/core
  // itself ("isThreadTitlePinned" is not exported). So the build keeps the
  // default externals and ships ~200M of node_modules. Revisit on upgrade.
  agents: { 'parley-action': agent },
  server: { apiRoutes: createParleyRoutes(store, mcp, serverUrl ? [WEB_SEARCH_CATALOG] : []) },
});
