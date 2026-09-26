/**
 * Dummy MCP server: an in-memory notes list with one read and two writes.
 * It ships as the default (`mcp-servers.example.json`) so act mode works
 * out of the box: "what are my notes" reads free, "note down milk" and
 * "delete the milk note" suspend for a tap each. State resets whenever
 * the server restarts — it is a toy, not storage.
 */
import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server/stdio';
import { z } from 'zod';

const server = new McpServer({ name: 'notes', version: '0.1.0' });
let notes = [
  { id: 'n1', text: 'water the plants' },
  { id: 'n2', text: 'read the act-mode manual' },
];
let nextId = 3;

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
  'add_note',
  {
    description: 'Add a note to the list',
    inputSchema: z.object({ text: z.string().min(1) }),
    annotations: { readOnlyHint: false },
  },
  async ({ text }) => {
    const id = `n${nextId++}`;
    notes = [...notes, { id, text }];
    return {
      content: [{ type: 'text', text: JSON.stringify({ added: id, total: notes.length }) }],
      structuredContent: { added: id, total: notes.length },
    };
  }
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
