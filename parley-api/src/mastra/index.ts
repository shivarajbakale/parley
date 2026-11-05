import { Mastra } from '@mastra/core/mastra';
import { screenExplainer } from './agents/screen-explainer.js';

export const mastra = new Mastra({
  agents: { screenExplainer },
});
