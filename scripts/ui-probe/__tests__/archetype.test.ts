import { describe, expect, it } from 'vitest';

import { B1, B2, B3, B4 } from '../rules/archetype';
import { makeSnapshot, type NodeSpec } from './factory';

const panel = (over: NodeSpec): NodeSpec => ({ data: { panel: '' }, ...over });

describe('B1 — list-detail', () => {
  it('flags a detail pane wider than its master', () => {
    // The measured inversion: master 476px, empty detail 660px.
    const s = makeSnapshot([
      { data: { archetype: 'list-detail' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, box: { x: 0, y: 0, width: 476, height: 700 } }),
      { parent: 0, role: 'separator', box: { x: 476, y: 0, width: 4, height: 700 } },
      panel({ parent: 0, box: { x: 480, y: 0, width: 660, height: 700 }, text: 'Nothing selected' }),
    ]);
    const messages = B1.check(s).map((v) => v.message);
    expect(messages.some((m) => m.includes('master pane'))).toBe(true);
  });

  it('accepts a master wider than the detail, with a handle and a non-blank detail', () => {
    const s = makeSnapshot([
      { data: { archetype: 'list-detail' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, box: { x: 0, y: 0, width: 700, height: 700 }, text: 'Billing v2' }),
      { parent: 0, role: 'separator', box: { x: 700, y: 0, width: 4, height: 700 } },
      panel({ parent: 0, box: { x: 704, y: 0, width: 456, height: 700 }, text: 'Nothing selected' }),
    ]);
    expect(B1.check(s)).toEqual([]);
  });

  it('flags a missing resize affordance', () => {
    const s = makeSnapshot([
      { data: { archetype: 'list-detail' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, box: { x: 0, y: 0, width: 700, height: 700 }, text: 'a' }),
      panel({ parent: 0, box: { x: 704, y: 0, width: 456, height: 700 }, text: 'b' }),
    ]);
    expect(B1.check(s).some((v) => v.message.includes('resize'))).toBe(true);
  });

  it('flags a blank detail pane — an empty state is content, not nothing', () => {
    const s = makeSnapshot([
      { data: { archetype: 'list-detail' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, box: { x: 0, y: 0, width: 700, height: 700 }, text: 'a' }),
      { parent: 0, role: 'separator', box: { x: 700, y: 0, width: 4, height: 700 } },
      panel({ parent: 0, box: { x: 704, y: 0, width: 456, height: 700 } }),
    ]);
    expect(B1.check(s).some((v) => v.message.includes('empty state'))).toBe(true);
  });

  it('flags anything other than two panes', () => {
    const s = makeSnapshot([
      { data: { archetype: 'list-detail' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, box: { x: 0, y: 0, width: 380, height: 700 }, text: 'a' }),
      panel({ parent: 0, box: { x: 390, y: 0, width: 380, height: 700 }, text: 'b' }),
      panel({ parent: 0, box: { x: 780, y: 0, width: 380, height: 700 }, text: 'c' }),
    ]);
    expect(B1.check(s).some((v) => v.message.includes('exactly two'))).toBe(true);
  });

  it('is silent on a different archetype', () => {
    expect(B1.check(makeSnapshot([{ data: { archetype: 'form' } }]))).toEqual([]);
  });
});

describe('B2 — dashboard-grid', () => {
  const kpiRow = (widths: number[]): NodeSpec[] => [
    { data: { archetype: 'dashboard-grid' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
    ...widths.map((w, i) =>
      panel({
        parent: 0,
        text: `kpi${i}`,
        box: { x: widths.slice(0, i).reduce((a, b) => a + b, 0), y: 0, width: w, height: 90 },
      })
    ),
  ];

  it('accepts a row of four equal tiles', () => {
    expect(B2.check(makeSnapshot(kpiRow([290, 290, 290, 290])))).toEqual([]);
  });

  it('flags a KPI row with more than four tiles', () => {
    const out = B2.check(makeSnapshot(kpiRow([232, 232, 232, 232, 232])));
    expect(out.some((v) => v.message.includes('2-4 tiles'))).toBe(true);
  });

  it('flags unequal tile widths', () => {
    const out = B2.check(makeSnapshot(kpiRow([400, 290, 290, 180])));
    expect(out.some((v) => v.message.includes('equal width'))).toBe(true);
  });

  it('flags a panel stretched to match a taller sibling', () => {
    const s = makeSnapshot([
      { data: { archetype: 'dashboard-grid' }, box: { x: 0, y: 0, width: 1160, height: 900 } },
      panel({ parent: 0, text: 'a', box: { x: 0, y: 0, width: 580, height: 90 } }),
      panel({ parent: 0, text: 'b', box: { x: 580, y: 0, width: 580, height: 90 } }),
      // Two 500px panels side by side; the right one only has 100px of ink.
      panel({ parent: 0, box: { x: 0, y: 100, width: 580, height: 500 } }),
      { parent: 3, text: 'chart', box: { x: 0, y: 100, width: 580, height: 480 } },
      panel({ parent: 0, box: { x: 580, y: 100, width: 580, height: 500 } }),
      { parent: 5, text: 'Getting started', box: { x: 580, y: 100, width: 580, height: 100 } },
    ]);
    expect(B2.check(s).some((v) => v.message.includes('stretched'))).toBe(true);
  });

  it('allows exactly one panel to absorb leftover height', () => {
    const s = makeSnapshot([
      { data: { archetype: 'dashboard-grid' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      panel({ parent: 0, text: 'a', data: { panel: '', fill: '' }, box: { x: 0, y: 0, width: 580, height: 90 } }),
      panel({ parent: 0, text: 'b', data: { panel: '', fill: '' }, box: { x: 580, y: 0, width: 580, height: 90 } }),
    ]);
    expect(B2.check(s).some((v) => v.message.includes('data-fill'))).toBe(true);
  });
});

describe('B3 — form', () => {
  const form = (over: NodeSpec = {}): ReturnType<typeof makeSnapshot> =>
    makeSnapshot([
      { data: { archetype: 'form' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      { parent: 0, tag: 'form', box: { x: 0, y: 0, width: 560, height: 400 }, ...over },
      { parent: 1, tag: 'label', text: 'Name', box: { x: 0, y: 0, width: 560, height: 16 } },
      { parent: 1, tag: 'input', box: { x: 0, y: 20, width: 560, height: 32 } },
      { parent: 1, tag: 'button', text: 'Save', box: { x: 0, y: 60, width: 100, height: 32 }, data: { submit: '' } },
    ]);

  it('accepts a single 560px column with a label above its control', () => {
    expect(B3.check(form())).toEqual([]);
  });

  it('flags a form wider than 640px', () => {
    const out = B3.check(form({ box: { x: 0, y: 0, width: 900, height: 400 } }));
    expect(out.some((v) => v.message.includes('640'))).toBe(true);
  });

  it('flags a label placed beside its control instead of above it', () => {
    const s = makeSnapshot([
      { data: { archetype: 'form' }, box: { x: 0, y: 0, width: 1160, height: 700 } },
      { parent: 0, tag: 'form', box: { x: 0, y: 0, width: 560, height: 400 } },
      { parent: 1, tag: 'label', text: 'Name', box: { x: 0, y: 20, width: 120, height: 32 } },
      { parent: 1, tag: 'input', box: { x: 130, y: 20, width: 430, height: 32 } },
      { parent: 1, tag: 'button', text: 'Save', box: { x: 0, y: 60, width: 100, height: 32 }, data: { submit: '' } },
    ]);
    expect(B3.check(s).some((v) => v.message.includes('above'))).toBe(true);
  });

  it('flags two submit actions', () => {
    const s = form();
    s.nodes.push({
      ...s.nodes[4],
      id: s.nodes.length,
      text: 'Save and close',
      box: { x: 110, y: 60, width: 140, height: 32 },
    });
    s.nodes[1].children.push(s.nodes.length - 1);
    expect(B3.check(s).some((v) => v.message.includes('one submit'))).toBe(true);
  });
});

describe('B4 — centered-card', () => {
  const centered = (over: NodeSpec = {}): ReturnType<typeof makeSnapshot> =>
    makeSnapshot([
      { data: { archetype: 'centered-card' }, box: { x: 0, y: 0, width: 1440, height: 900 } },
      panel({ parent: 0, text: 'Sign in', box: { x: 520, y: 250, width: 400, height: 400 }, ...over }),
    ]);

  it('accepts one 400px card centred in its frame', () => {
    expect(B4.check(centered())).toEqual([]);
  });

  it('flags a card wider than 480px', () => {
    expect(
      B4.check(centered({ box: { x: 420, y: 250, width: 600, height: 400 } })).some((v) =>
        v.message.includes('480')
      )
    ).toBe(true);
  });

  it('flags a card that is not centred', () => {
    expect(
      B4.check(centered({ box: { x: 40, y: 250, width: 400, height: 400 } })).some((v) =>
        v.message.includes('centred')
      )
    ).toBe(true);
  });

  it('flags a scroller inside a centred card view', () => {
    const s = centered();
    s.nodes[1].style.overflowY = 'auto';
    s.nodes[1].scrollHeight = 900;
    s.nodes[1].clientHeight = 400;
    expect(B4.check(s).some((v) => v.message.includes('scroll'))).toBe(true);
  });
});
