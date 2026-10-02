import { describe, expect, it, vi } from 'vitest';

import { createRewriter, RewriteError } from '../rewriter';

const SERVER = 'http://localhost:3100';

const reply = (content: unknown, status = 200) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status });

function setup(fetchFn: typeof fetch) {
  return createRewriter({ serverUrl: () => SERVER, fetchFn });
}

describe('rewriter', () => {
  it('sends the text and the instruction to MiniMax through the Parley server, with no key', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('  Hi.  '));
    await expect(setup(fetchFn).rewrite('Hello there, friend.', 'make it shorter')).resolves.toBe(
      'Hi.'
    );

    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe(`${SERVER}/api/providers/minimax/v1/chat/completions`);
    expect(init.headers).toEqual({ 'Content-Type': 'application/json' });
    const body = JSON.parse(init.body);
    expect(body.thinking).toEqual({ type: 'disabled' });
    expect(body.messages[1].content).toContain('<text>\nHello there, friend.\n</text>');
    expect(body.messages[1].content).toContain('<instruction>\nmake it shorter\n</instruction>');
  });

  it('drops inline thinking from the reply', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('<think>shorter, ok</think>\nHi.'));
    await expect(setup(fetchFn).rewrite('Hello', 'shorter')).resolves.toBe('Hi.');
  });

  it('refuses an empty rewrite, which would erase the field', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('<think>hm</think>'));
    await expect(setup(fetchFn).rewrite('Hello', 'shorter')).rejects.toMatchObject({
      kind: 'empty',
    });
  });

  it('says the key is missing on the server when the server answers no_key', async () => {
    const fetchFn = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify({ error: { code: 'no_key' } }), { status: 503 }));
    await expect(setup(fetchFn).rewrite('a', 'b')).rejects.toMatchObject({
      kind: 'no_key',
      message: 'No MiniMax key on the Parley server',
    });
  });

  it.each([
    [401, 'auth'],
    [429, 'rate_limit'],
    [500, 'server'],
  ])('maps HTTP %i to %s', async (status, kind) => {
    const fetchFn = vi.fn().mockResolvedValue(reply('x', status));
    await expect(setup(fetchFn).rewrite('a', 'b')).rejects.toMatchObject({ kind });
  });

  it('says the server is not running on a refused connection, and maps a non-JSON 200 to server', async () => {
    await expect(
      setup(vi.fn().mockRejectedValue(new TypeError('fetch failed'))).rewrite('a', 'b')
    ).rejects.toMatchObject({ kind: 'offline', message: 'Parley server not running' });
    await expect(
      setup(vi.fn().mockResolvedValue(new Response('<html>', { status: 200 }))).rewrite('a', 'b')
    ).rejects.toBeInstanceOf(RewriteError);
  });
});
