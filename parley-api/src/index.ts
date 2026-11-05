import express, { type Request, type Response } from 'express';
import { MastraServer } from '@mastra/express';
import { createExplainRouter } from './explain/route.js';
import { createKeysRouter, defaultKeyFile, loadKeyFile } from './providers/keys.js';
import { createProvidersRouter } from './providers/route.js';
import { createSearchRouter } from './search/route.js';
import { exaFromEnv, searchWeb } from './mastra/tools/exa-search.js';
import { answerWithoutTools } from './mastra/agents/screen-explainer.js';
import { mastra } from './mastra/index.js';

// Keys saved from the app's settings window win over .env; load them before
// anything reads a key.
const KEYS_FILE = defaultKeyFile();
const loadedKeys = loadKeyFile(KEYS_FILE, process.env);
if (loadedKeys) console.log(`Loaded ${loadedKeys} provider key setting(s) from ${KEYS_FILE}`);

const app = express();
// 3100: the desktop app's default Parley server address (settings syncUrl).
const PORT = Number(process.env.PORT) || 3100;
// Loopback only: /api/providers spends real keys, so nothing off this Mac may reach it.
const HOST = process.env.HOST || '127.0.0.1';

// Setting a key from the app. Its own small JSON parser; mounted first.
app.use('/api/providers/keys', express.json({ limit: '4kb' }), createKeysRouter({ file: KEYS_FILE }));
// Provider calls with the keys added. Before express.json(): bodies pass through raw.
app.use('/api/providers', createProvidersRouter());

app.use(express.json());

// The Explain card's stream. Mounted before Mastra so its /api routes cannot shadow it.
app.use(
  '/api/explain',
  createExplainRouter({
    stream: async (messages, signal, retry) => {
      const options = retry ? { abortSignal: signal, ...answerWithoutTools(retry.found) } : { abortSignal: signal };
      const output = await mastra.getAgent('screenExplainer').stream(messages, options);
      return output.fullStream;
    },
  }),
);

// Web search for the act-mode agent, with the Exa key added here.
app.use('/api/search', createSearchRouter({ search: (query) => searchWeb(query, exaFromEnv()) }));

// Registers Mastra's routes (agents, workflows, ...) under /api.
const server = new MastraServer({ app, mastra });
await server.init();

app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Parley API' });
});

app.listen(PORT, HOST, () => {
  console.log(`Server is running on http://${HOST}:${PORT}`);
});
