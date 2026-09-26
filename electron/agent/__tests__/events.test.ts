import { describe, expect, it, vi } from 'vitest';

import { createSseParser, parseAgentEvent, type SseRawEvent } from '../events';

describe('SSE parser', () => {
  it('dispatches one event per blank line with its type and data', () => {
    const seen: SseRawEvent[] = [];
    const parser = createSseParser(raw => seen.push(raw));
    parser.push('event: step\ndata: {"runId":"r1","seq":1,"text":"hi"}\n\n');
    expect(seen).toEqual([{ event: 'step', data: '{"runId":"r1","seq":1,"text":"hi"}' }]);
  });

  it('joins multi-line data with newlines', () => {
    const seen: SseRawEvent[] = [];
    const parser = createSseParser(raw => seen.push(raw));
    parser.push('event: step\ndata: {"a":\ndata: 1}\n\n');
    expect(seen).toEqual([{ event: 'step', data: '{"a":\n1}' }]);
  });

  it('ignores colon comments, so heartbeats never dispatch', () => {
    const onEvent = vi.fn();
    const parser = createSseParser(onEvent);
    parser.push(':ping\n\n: ping\n\nevent: step\ndata: {}\n\n');
    expect(onEvent).toHaveBeenCalledTimes(1);
  });

  it('holds partial chunks until the blank line arrives', () => {
    const seen: SseRawEvent[] = [];
    const parser = createSseParser(raw => seen.push(raw));
    parser.push('event: ste');
    parser.push('p\ndata: {"runId"');
    expect(seen).toEqual([]);
    parser.push(':"r1"}\n\n');
    expect(seen).toEqual([{ event: 'step', data: '{"runId":"r1"}' }]);
  });

  it('tolerates CRLF line endings', () => {
    const seen: SseRawEvent[] = [];
    const parser = createSseParser(raw => seen.push(raw));
    parser.push('event: step\r\ndata: {"runId":"r1"}\r\n\r\n');
    expect(seen).toEqual([{ event: 'step', data: '{"runId":"r1"}' }]);
  });
});

describe('parseAgentEvent', () => {
  it('parses a step with its text', () => {
    expect(
      parseAgentEvent({ event: 'step', data: '{"runId":"r1","seq":2,"text":"Checking…"}' })
    ).toEqual({ kind: 'step', runId: 'r1', seq: 2, text: 'Checking…' });
  });

  it('parses an approval with call, summary and transcript', () => {
    expect(
      parseAgentEvent({
        event: 'approval_requested',
        data: '{"runId":"r1","seq":3,"callId":"c9","tool":"book_event","summary":"Book dentist?","transcript":"book dentist tuesday"}',
      })
    ).toEqual({
      kind: 'approval_requested',
      runId: 'r1',
      seq: 3,
      callId: 'c9',
      tool: 'book_event',
      summary: 'Book dentist?',
      transcript: 'book dentist tuesday',
    });
  });

  it('parses completed and failed terminals', () => {
    expect(
      parseAgentEvent({ event: 'completed', data: '{"runId":"r1","seq":9,"text":"Booked"}' })
    ).toEqual({ kind: 'completed', runId: 'r1', seq: 9, text: 'Booked' });
    expect(
      parseAgentEvent({ event: 'failed', data: '{"runId":"r1","seq":9,"message":"boom"}' })
    ).toEqual({ kind: 'failed', runId: 'r1', seq: 9, message: 'boom' });
  });

  it('drops non-JSON data, unknown types and mistyped fields instead of throwing', () => {
    expect(parseAgentEvent({ event: 'step', data: 'not json' })).toBeNull();
    expect(parseAgentEvent({ event: 'step', data: '[1,2]' })).toBeNull();
    expect(parseAgentEvent({ event: 'mystery', data: '{"runId":"r1","seq":1}' })).toBeNull();
    expect(parseAgentEvent({ event: 'step', data: '{"runId":"r1","seq":"2"}' })).toBeNull();
    expect(parseAgentEvent({ event: 'step', data: '{"runId":"r1","seq":2}' })).toBeNull();
    expect(
      parseAgentEvent({ event: 'completed', data: '{"runId":"r1","seq":2,"text":42}' })
    ).toBeNull();
    expect(
      parseAgentEvent({
        event: 'approval_requested',
        data: '{"runId":"r1","seq":2,"callId":"c1","tool":"t"}',
      })
    ).toBeNull();
  });
});
