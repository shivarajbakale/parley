import { describe, expect, it, vi } from 'vitest';

import { createRewriter, RewriteError } from '../rewriter';

const reply = (content: unknown, status = 200) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status });

function setup(fetchFn: typeof fetch, key: string | null = 'mm-key') {
  return createRewriter({ getApiKey: () => key, fetchFn });
}

describe('rewriter', () => {
  it('sends the text and the instruction to MiniMax and returns the rewrite', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('  Hi.  '));
    await expect(setup(fetchFn).rewrite('Hello there, friend.', 'make it shorter')).resolves.toBe(
      'Hi.'
    );

    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe('https://api.minimax.io/v1/chat/completions');
    expect(init.headers.Authorization).toBe('Bearer mm-key');
    const body = JSON.parse(init.body);
    expect(body.thinking).toEqual({ type: 'disabled' });
    expect(body.messages[1].content).toContain('<text>\nHello there, friend.\n</text>');
    expect(body.messages[1].content).toContain('<instruction>\nmake it shorter\n</instruction>');
  });

  it('asks for a short markdown explanation and caps the reply', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply(' Same result if repeated. '));
    await expect(setup(fetchFn).explain('idempotent')).resolves.toBe('Same result if repeated.');

    const body = JSON.parse(fetchFn.mock.calls[0][1].body);
    expect(body.messages[0].content).toContain('80 words');
    // MiniMax answers in Chinese unless told otherwise.
    expect(body.messages[0].content).toContain('Always write in English');
    expect(body.messages[1].content).toBe('<text>\nidempotent\n</text>');
    expect(body.max_completion_tokens).toBeGreaterThan(0);
  });

  it('sends a spoken question beside the text', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('Yes.'));
    await setup(fetchFn).explain('idempotent', 'is it safe to retry?');
    const body = JSON.parse(fetchFn.mock.calls[0][1].body);
    expect(body.messages[1].content).toBe(
      '<text>\nidempotent\n</text>\n<question>\nis it safe to retry?\n</question>'
    );
  });

  it('fails an explanation without a key, or with an empty reply', async () => {
    await expect(setup(vi.fn(), null).explain('x')).rejects.toMatchObject({ kind: 'no_key' });
    const fetchFn = vi.fn().mockResolvedValue(reply('<think>hm</think>'));
    await expect(setup(fetchFn).explain('x')).rejects.toMatchObject({ kind: 'empty' });
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

  it('fails without a key before any request', async () => {
    const fetchFn = vi.fn();
    await expect(setup(fetchFn, null).rewrite('a', 'b')).rejects.toMatchObject({ kind: 'no_key' });
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it.each([
    [401, 'auth'],
    [429, 'rate_limit'],
    [500, 'server'],
  ])('maps HTTP %i to %s', async (status, kind) => {
    const fetchFn = vi.fn().mockResolvedValue(reply('x', status));
    await expect(setup(fetchFn).rewrite('a', 'b')).rejects.toMatchObject({ kind });
  });

  it('maps a transport failure to network, and a non-JSON 200 to server', async () => {
    await expect(
      setup(vi.fn().mockRejectedValue(new Error('offline'))).rewrite('a', 'b')
    ).rejects.toBeInstanceOf(RewriteError);
    await expect(
      setup(vi.fn().mockResolvedValue(new Response('<html>', { status: 200 }))).rewrite('a', 'b')
    ).rejects.toMatchObject({ kind: 'server' });
  });

  it('tests a key with a one-token request', async () => {
    const fetchFn = vi.fn().mockResolvedValue(reply('o'));
    await expect(setup(fetchFn).testKey('candidate')).resolves.toEqual({
      ok: true,
      message: 'Key works',
    });
    const [, init] = fetchFn.mock.calls[0];
    expect(init.headers.Authorization).toBe('Bearer candidate');
    expect(JSON.parse(init.body).max_completion_tokens).toBe(1);

    const bad = setup(vi.fn().mockResolvedValue(reply('', 401)));
    await expect(bad.testKey('nope')).resolves.toEqual({ ok: false, message: 'Invalid MiniMax key' });
  });
});
