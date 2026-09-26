import type { Agent } from '@mastra/core/agent';
import { Mastra } from '@mastra/core/mastra';

import { createParleyAgent } from './agents/parley-action';
import { createMcpClient, listCatalog, loadServerDefinitions } from './parley/mcp';
import { createRunStore } from './parley/runs';
import { createParleyRoutes } from './parley/routes';

/**
 * Parley's agent server. One agent, `parley-action`, works voice commands
 * through the configured MCP servers; six `/parley/*` routes carry runs,
 * approvals and health back to the desktop app.
 *
 * The model is `PARLEY_MODEL` (a Mastra `provider/id` string, default
 * Groq's gpt-oss) or `mock:<read|write|plain>` for keyless end-to-end
 * verification — see `parley/mock.ts`.
 */

const MODEL_FALLBACK = 'groq/openai/gpt-oss-20b';

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
const descriptions = new Map<string, string>();
for (const [name, tool] of Object.entries(tools)) {
  const description = (tool as { description?: unknown }).description;
  if (typeof description === 'string' && description) descriptions.set(name, description);
}

const agent = createParleyAgent({ model: await resolveModel(), tools });
const store = createRunStore(agent, descriptions);

const catalog = await listCatalog(mcp).catch(() => []);
console.log(
  `[parley] serving ${Object.keys(tools).length} tools from ${catalog.map(entry => entry.name).join(', ') || 'no servers'}`
);

export const mastra = new Mastra({
  // NOTE: `bundler.externals: false` (one self-contained bundle, no
  // node_modules) fails on mastra 1.30: Rollup chokes inside @mastra/core
  // itself ("isThreadTitlePinned" is not exported). So the build keeps the
  // default externals and ships ~200M of node_modules. Revisit on upgrade.
  agents: { 'parley-action': agent },
  server: { apiRoutes: createParleyRoutes(store, mcp) },
});
