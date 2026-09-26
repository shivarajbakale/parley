import { access, readFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, resolve } from 'node:path';

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
 * With no file of its own, the server falls back to the shipped
 * `./mcp-servers.example.json` (the dummy notes server), so act mode
 * works out of the box. An explicitly named file that is missing fails
 * the boot instead — a typo must not silently boot the dummy. A
 * malformed file fails out loud: silently running with half the
 * servers would be worse.
 *
 * Relative script paths in `args` resolve against the directory of the
 * file that named them: neither the working directory (under `mastra dev`
 * the server runs from `src/mastra/public/`) nor the bundler's layout can
 * be trusted. A bare `node` command runs through `PARLEY_NODE_BIN` when
 * set — the packaged app has no system node, so Parley points it at
 * Electron-as-Node.
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
  if (record.args !== undefined) {
    if (!Array.isArray(record.args) || record.args.some(arg => typeof arg !== 'string')) return false;
  }
  if (typeof record.command === 'string') return true;
  return typeof record.url === 'string';
}

/** The project root: first directory walking up from the working
 * directory that holds a package.json (`PARLEY_AGENT_ROOT` overrides).
 * The walk is what finds the project when the server runs from
 * `src/mastra/public/` under `mastra dev`. */
export async function findProjectRoot(): Promise<string> {
  const override = process.env.PARLEY_AGENT_ROOT;
  if (override) return override;
  let dir = process.cwd();
  for (;;) {
    try {
      await access(join(dir, 'package.json'));
      return dir;
    } catch {
      const parent = dirname(dir);
      if (parent === dir) return process.cwd();
      dir = parent;
    }
  }
}

async function readServersFile(file: string): Promise<string | null> {
  try {
    return await readFile(file, 'utf8');
  } catch (error) {
    if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') return null;
    throw new Error(`could not read MCP servers file ${file}: ${(error as Error).message}`);
  }
}

/** A relative arg pointing at a script, not a flag or a package name. */
const SCRIPT_EXTENSIONS = ['.mjs', '.cjs', '.js', '.py', '.sh'];

function resolveArgs(args: string[] | undefined, root: string): string[] | undefined {
  if (!args) return undefined;
  return args.map(arg => {
    if (isAbsolute(arg)) return arg;
    if (!SCRIPT_EXTENSIONS.some(extension => arg.endsWith(extension))) return arg;
    return join(root, arg);
  });
}

export async function loadServerDefinitions(): Promise<Record<string, ServerDefinition>> {
  const configured = process.env.PARLEY_MCP_SERVERS_FILE;
  const root = await findProjectRoot();
  if (configured) {
    const raw = await readServersFile(configured);
    if (raw === null) throw new Error(`MCP servers file ${configured} not found`);
    return parseServerDefinitions(raw, configured, dirname(resolve(configured)));
  }
  const file = join(root, 'mcp-servers.json');
  const example = join(root, 'mcp-servers.example.json');
  const raw = (await readServersFile(file)) ?? (await readServersFile(example));
  if (raw === null) return {};
  return parseServerDefinitions(raw, file, root);
}

function parseServerDefinitions(
  raw: string,
  source: string,
  root: string
): Record<string, ServerDefinition> {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    throw new Error(`MCP servers file ${source} is not JSON`);
  }
  const servers =
    typeof parsed === 'object' && parsed !== null && 'servers' in parsed
      ? (parsed as Record<string, unknown>).servers
      : parsed;
  if (typeof servers !== 'object' || servers === null || Array.isArray(servers)) {
    throw new Error(`MCP servers file ${source} must hold an object of servers`);
  }
  const out: Record<string, ServerDefinition> = {};
  for (const [name, definition] of Object.entries(servers as Record<string, unknown>)) {
    if (!isDefinition(definition)) {
      throw new Error(`MCP server "${name}" in ${source} needs a command or a url`);
    }
    out[name] = { ...definition, args: resolveArgs(definition.args, root) };
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
  const nodeBin = process.env.PARLEY_NODE_BIN;
  const withPolicy: Record<string, MastraMCPServerDefinition> = {};
  for (const [name, server] of Object.entries(servers)) {
    const approval = (ctx: RequireToolApprovalContext): boolean =>
      needsApproval(ctx.toolName, ctx.annotations);
    if (server.command !== undefined) {
      const command = server.command === 'node' && nodeBin ? nodeBin : server.command;
      withPolicy[name] = { command, args: server.args, env: server.env, requireToolApproval: approval };
    } else {
      withPolicy[name] = { url: new URL(server.url as string), requireToolApproval: approval };
    }
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
