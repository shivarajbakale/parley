import { describe, expect, it } from 'vitest';
import { ANSWER_NOW, MAX_STEPS, SEARCH_STEPS, answerAfterSearching } from '../src/mastra/agents/screen-explainer.js';

const base = [{ role: 'system', content: 'instructions' }];

describe('answerAfterSearching', () => {
  it('leaves tools on for the search steps', () => {
    for (let step = 0; step < SEARCH_STEPS; step += 1) {
      expect(answerAfterSearching({ stepNumber: step, systemMessages: base })).toBeUndefined();
    }
  });

  it('withholds the tools after them and tells the model to answer, keeping its instructions', () => {
    for (let step = SEARCH_STEPS; step < MAX_STEPS; step += 1) {
      expect(answerAfterSearching({ stepNumber: step, systemMessages: base })).toEqual({
        toolChoice: 'none',
        activeTools: [],
        systemMessages: [...base, { role: 'system', content: ANSWER_NOW }],
      });
    }
  });

  it('leaves at least two answer-only steps', () => {
    expect(MAX_STEPS - SEARCH_STEPS).toBeGreaterThanOrEqual(2);
  });
});
