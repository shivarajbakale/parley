import { readFile } from 'node:fs/promises';

import {
  MCPClient,
  type MastraMCPServerDefinition,
  type RequireToolApprovalContext,
  type ToolAnnotations,
} from '@mastra/mcp';

/**
 * The MCP servers a voice command can act through. They come from a JSON
 * file (default `./mcp-servers.json`, overridable with
 * `PARLEY_MCP_SERVERS_FILE`) shaped like the MCPClient `servers` map:
 *
 *   { "calendar": { "command": "npx", "args": ["-y", "calendar-mcp"] },
 *     "github": { "url": "http://localhost:3000/mcp" } }
 *
 * A missing file means no servers, not an error: the Agent tab says so and
 * the gesture blocks until one is connected. A malformed file fails the
 * boot out loud — silently running with half the servers would be worse.
 */

export interface McpCatalogEntry {
  name: string;
  tools: number;
}

interface ServerDefinition {
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  url?: string;
}

function isDefinition(value: unknown): value is ServerDefinition {
  if (typeof value !== 'object' || value === null) return false;
  const record = value as Record<string, unknown>;
  if (typeof record.command === 'string') return true;
  return typeof record.url === 'string';
}

export async function loadServerDefinitions(): Promise<Record<string, ServerDefinition>> {
  const file = process.env.PARLEY_MCP_SERVERS_FILE ?? './mcp-servers.json';
  let raw: string;
  try {
    raw = await readFile(file, 'utf8');
  } catch (error) {
    if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') return {};
    throw new Error(`could not read MCP servers file ${file}: ${(error as Error).message}`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    throw new Error(`MCP servers file ${file} is not JSON`);
  }
  const servers =
    typeof parsed === 'object' && parsed !== null && 'servers' in parsed
      ? (parsed as Record<string, unknown>).servers
      : parsed;
  if (typeof servers !== 'object' || servers === null || Array.isArray(servers)) {
    throw new Error(`MCP servers file ${file} must hold an object of servers`);
  }
  const out: Record<string, ServerDefinition> = {};
  for (const [name, definition] of Object.entries(servers as Record<string, unknown>)) {
    if (!isDefinition(definition)) {
      throw new Error(`MCP server "${name}" in ${file} needs a command or a url`);
    }
    out[name] = definition;
  }
  return out;
}

/** Reads run their tool free; everything else suspends for a tap. Writes
 * are the default: an unknown tool asks rather than acts. */
const READ_PREFIXES = ['list', 'get', 'read', 'search', 'show', 'describe', 'fetch', 'find'];

function isReadTool(toolName: string, annotations: ToolAnnotations | undefined): boolean {
  if (annotations?.readOnlyHint === true) return true;
  const bare = toolName.includes('_') ? toolName.slice(toolName.indexOf('_') + 1) : toolName;
  const lower = bare.toLowerCase();
  return READ_PREFIXES.some(prefix => lower === prefix || lower.startsWith(`${prefix}_`));
}

export function needsApproval(toolName: string, annotations?: ToolAnnotations): boolean {
  return !isReadTool(toolName, annotations);
}

export function createMcpClient(servers: Record<string, ServerDefinition>): MCPClient {
  const withPolicy: Record<string, MastraMCPServerDefinition> = {};
  for (const [name, server] of Object.entries(servers)) {
    const approval = (ctx: RequireToolApprovalContext): boolean =>
      needsApproval(ctx.toolName, ctx.annotations);
    withPolicy[name] =
      server.command !== undefined
        ? { command: server.command, args: server.args, env: server.env, requireToolApproval: approval }
        : { url: new URL(server.url as string), requireToolApproval: approval };
  }
  return new MCPClient({ id: 'parley-mcp', servers: withPolicy });
}

/** The Agent tab's server list: one row per reachable server. Servers that
 * fail discovery are left out — health names what is usable, not what is
 * configured. */
export async function listCatalog(client: MCPClient): Promise<McpCatalogEntry[]> {
  const { definitions } = await client.listToolDefinitionsWithErrors({ perServerTimeoutMs: 3000 });
  return Object.entries(definitions).map(([name, tools]) => ({
    name,
    tools: Object.keys(tools).length,
  }));
}
