import { describe, expect, it } from 'vitest';
import { MAX_STEPS, finalStepAnswers } from '../src/mastra/agents/screen-explainer.js';

describe('finalStepAnswers', () => {
  it('leaves tools on before the last step', () => {
    for (let step = 0; step < MAX_STEPS - 1; step += 1) {
      expect(finalStepAnswers({ stepNumber: step })).toBeUndefined();
    }
  });

  it('turns tools off on the last step so the run ends in an answer', () => {
    expect(finalStepAnswers({ stepNumber: MAX_STEPS - 1 })).toEqual({ toolChoice: 'none' });
  });
});
