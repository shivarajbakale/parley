/**
 * Smoke fixture: a two-tool notes server over stdio. `list_notes` is
 * annotated read-only (runs free); `delete_note` is a write (suspends for
 * approval). State is in-memory and seeded the same on every boot, so the
 * smoke run is deterministic.
 */
import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server/stdio';
import { z } from 'zod';

const server = new McpServer({ name: 'parley-smoke', version: '0.1.0' });
let notes = [
  { id: 'n1', text: 'buy milk' },
  { id: 'n2', text: 'call Ada' },
];

server.registerTool(
  'list_notes',
  {
    description: 'List the current notes',
    inputSchema: z.object({}),
    annotations: { readOnlyHint: true },
  },
  async () => ({
    content: [{ type: 'text', text: JSON.stringify(notes) }],
    structuredContent: { notes },
  })
);

server.registerTool(
  'delete_note',
  {
    description: 'Delete a note by id',
    inputSchema: z.object({ id: z.string() }),
    annotations: { readOnlyHint: false, destructiveHint: true },
  },
  async ({ id }) => {
    notes = notes.filter(note => note.id !== id);
    return {
      content: [{ type: 'text', text: JSON.stringify({ deleted: id, remaining: notes.length }) }],
      structuredContent: { deleted: id, remaining: notes.length },
    };
  }
);

await server.connect(new StdioServerTransport());
