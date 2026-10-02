import express, { type Request, type Response } from 'express';
import { MastraServer } from '@mastra/express';
import { createExplainRouter } from './explain/route.js';
import { createProvidersRouter } from './providers/route.js';
import { answerWithoutTools } from './mastra/agents/screen-explainer.js';
import { mastra } from './mastra/index.js';

const app = express();
// 3100: the desktop app's default Parley server address (settings syncUrl).
const PORT = Number(process.env.PORT) || 3100;
// Loopback only: /api/providers spends real keys, so nothing off this Mac may reach it.
const HOST = process.env.HOST || '127.0.0.1';

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

// Registers Mastra's routes (agents, workflows, ...) under /api.
const server = new MastraServer({ app, mastra });
await server.init();

app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Parley API' });
});

app.listen(PORT, HOST, () => {
  console.log(`Server is running on http://${HOST}:${PORT}`);
});
