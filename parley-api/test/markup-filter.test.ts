import { describe, expect, it } from 'vitest';
import { createMarkupFilter } from '../src/explain/markup-filter.js';

const CALL =
  ']<]minimax[>[<tool_call>\n]<]minimax[>[<invoke name="webSearch">]<]minimax[>[<query>q]<]minimax[>[</query>]<]minimax[>[</invoke>\n]<]minimax[>[</tool_call>';

function run(pieces: string[]) {
  const f = createMarkupFilter();
  let text = '';
  let sawCall = false;
  for (const p of pieces) {
    const r = f.push(p);
    text += r.text;
    sawCall ||= r.sawCall;
  }
  return { text: text + f.end(), sawCall };
}

describe('createMarkupFilter', () => {
  it('passes ordinary text through, including a lone bracket', () => {
    expect(run(['a ]b', ' [c] <tool_call> is a tag name'])).toEqual({ text: 'a ]b [c] <tool_call> is a tag name', sawCall: false });
  });

  it('removes a whole fake tool call and reports it', () => {
    expect(run([`Before. ${CALL}`])).toEqual({ text: 'Before. ', sawCall: true });
  });

  it('removes a fake call split across many pieces, keeping text after it', () => {
    const whole = `${CALL}\nAfter.`;
    const pieces = whole.match(/.{1,3}/gs)!;
    expect(run(pieces)).toEqual({ text: 'After.', sawCall: true });
  });

  it('flushes a held partial marker that never completed', () => {
    expect(run(['tail ]<]mini'])).toEqual({ text: 'tail ]<]mini', sawCall: false });
  });
});
