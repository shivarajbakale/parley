import express, { type Request, type Response } from 'express';
import { MastraServer } from '@mastra/express';
import { mastra } from './mastra/index.js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Registers Mastra's routes (agents, workflows, ...) under /api.
const server = new MastraServer({ app, mastra });
await server.init();

app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Parley API' });
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
