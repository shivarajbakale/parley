import express, { type Request, type Response } from 'express';
import { MastraServer } from '@mastra/express';
import { createExplainRouter } from './explain/route.js';
import { mastra } from './mastra/index.js';

const app = express();
// 3100: the desktop app's default Parley server address (settings syncUrl).
const PORT = process.env.PORT || 3100;

app.use(express.json());

// The Explain card's stream. Mounted before Mastra so its /api routes cannot shadow it.
app.use(
  '/api/explain',
  createExplainRouter({
    stream: async (messages, signal) => {
      const output = await mastra.getAgent('screenExplainer').stream(messages, { abortSignal: signal });
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

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
