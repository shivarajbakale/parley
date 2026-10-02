import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import type { ExplainState, ParleyApi } from '../../../electron/types';
import { ExplainApp, ExplainCard } from '../ExplainCard';
import { tidyPartial } from '../tidy-partial';

const api = {
  copyExplain: vi.fn(),
  reportExplainHeight: vi.fn(),
  onExplain: vi.fn(),
  dismissExplain: vi.fn(),
  openExternal: vi.fn(),
};

const themed = (children: React.ReactNode) => (
  <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
    {children}
  </ThemeProvider>
);

const show = (state: ExplainState) => render(themed(<ExplainCard state={state} />));

beforeEach(() => {
  vi.clearAllMocks();
  window.parley = api as unknown as ParleyApi;
});

describe('ExplainCard', () => {
  it('shows a loading skeleton with no copy button', () => {
    show({ status: 'thread', turns: [{ status: 'loading' }], maxHeight: 500 });
    expect(screen.getByRole('status', { name: 'Explaining' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Copy' })).not.toBeInTheDocument();
  });

  it('closes from its own button, since it never takes the keyboard', async () => {
    show({ status: 'thread', turns: [{ status: 'loading' }], maxHeight: 500 });
    await userEvent.click(screen.getByRole('button', { name: 'Close' }));
    expect(api.dismissExplain).toHaveBeenCalledOnce();
  });

  it('renders the markdown answer and copies its source', async () => {
    show({
      status: 'thread',
      turns: [{ status: 'ready', markdown: 'It **means** x.\n\n- one\n- two' }],
      maxHeight: 500,
    });
    expect(screen.getByText('means').tagName).toBe('STRONG');
    expect(screen.getAllByRole('listitem')).toHaveLength(2);

    await userEvent.click(screen.getByRole('button', { name: 'Copy' }));
    expect(api.copyExplain).toHaveBeenCalledWith('It **means** x.\n\n- one\n- two');
  });

  it('never turns model output into markup or a link', () => {
    show({
      status: 'thread',
      turns: [{ status: 'ready', markdown: '<img src=x onerror=steal()> [go](https://evil.example)' }],
      maxHeight: 500,
    });
    expect(document.querySelector('img')).toBeNull();
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
    expect(screen.getByText('go')).toBeInTheDocument();
  });

  it('shows the question above its own answer, and marks a later turn as a follow-up', () => {
    show({
      status: 'thread',
      turns: [
        { question: 'what is this?', status: 'ready', markdown: 'A thing.' },
        { question: 'and why?', status: 'loading' },
      ],
      maxHeight: 500,
    });
    expect(screen.getByText('what is this?')).toBeInTheDocument();
    expect(screen.getByText('and why?')).toBeInTheDocument();
    expect(screen.getAllByRole('status', { name: 'Explaining' })).toHaveLength(1);
  });

  it('copies the latest ready answer, not an earlier one', async () => {
    show({
      status: 'thread',
      turns: [
        { question: 'a', status: 'ready', markdown: 'First.' },
        { question: 'b', status: 'ready', markdown: 'Second.' },
      ],
      maxHeight: 500,
    });
    await userEvent.click(screen.getByRole('button', { name: 'Copy' }));
    expect(api.copyExplain).toHaveBeenCalledWith('Second.');
  });

  it('says what to do when nothing was selected', () => {
    show({ status: 'empty', maxHeight: 500 });
    expect(screen.getByText('Select some text first')).toBeInTheDocument();
  });

  it('shows an error as an alert', () => {
    show({ status: 'thread', turns: [{ status: 'error', message: 'No MiniMax key' }], maxHeight: 500 });
    expect(screen.getByRole('alert')).toHaveTextContent('No MiniMax key');
  });

  it('shows a streaming answer as it grows, busy and with no copy button yet', () => {
    show({ status: 'thread', turns: [{ status: 'streaming', markdown: 'It **means**' }], maxHeight: 500 });
    expect(screen.getByText('means').tagName).toBe('STRONG');
    expect(screen.queryByRole('status', { name: 'Explaining' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Copy' })).not.toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Explanation' })).toHaveAttribute('aria-busy', 'true');
  });

  it('says what it is searching, before any text and under text already shown', () => {
    const { unmount } = show({ status: 'thread', turns: [{ status: 'loading', searching: 'Mastra 1.67' }], maxHeight: 500 });
    expect(screen.getByRole('status', { name: 'Searching' })).toHaveTextContent('Searching “Mastra 1.67”');
    unmount();

    show({
      status: 'thread',
      turns: [{ status: 'streaming', markdown: 'So far.', searching: 'more detail' }],
      maxHeight: 500,
    });
    expect(screen.getByText('So far.')).toBeInTheDocument();
    expect(screen.getByRole('status', { name: 'Searching' })).toHaveTextContent('Searching “more detail”');
  });

  it('lists the real sources by site and opens one in the browser', async () => {
    show({
      status: 'thread',
      turns: [
        {
          status: 'ready',
          markdown: 'Answer.',
          sources: [
            { title: 'Release notes', url: 'https://www.newreleases.io/mastra' },
            { title: 'Docs', url: 'https://docs.exa.ai/reference/highlights' },
          ],
        },
      ],
      maxHeight: 500,
    });
    const source = screen.getByRole('button', { name: 'newreleases.io' });
    expect(source).toHaveAttribute('title', 'Release notes');
    expect(screen.getByRole('button', { name: 'docs.exa.ai' })).toBeInTheDocument();
    await userEvent.click(source);
    expect(api.openExternal).toHaveBeenCalledWith('https://www.newreleases.io/mastra');
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });

  it('keeps the text that arrived before an error, above the error', () => {
    show({
      status: 'thread',
      turns: [{ status: 'error', message: 'The answer stopped early', markdown: 'Half an answer' }],
      maxHeight: 500,
    });
    expect(screen.getByText('Half an answer')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('The answer stopped early');
  });

  it('caps the card at the height main allows, so only past it does it scroll', () => {
    show({ status: 'thread', turns: [{ status: 'loading' }], maxHeight: 432 });
    expect(screen.getByRole('region', { name: 'Explanation' })).toHaveStyle({ maxHeight: '432px' });
  });
});

describe('ExplainApp', () => {
  it('paints nothing until main pushes a state, then shows it', async () => {
    let push: (state: ExplainState) => void = () => {};
    api.onExplain.mockImplementation((listener) => {
      push = listener;
      return () => {};
    });
    render(themed(<ExplainApp />));
    expect(screen.queryByText('Explain')).not.toBeInTheDocument();

    await act(async () => push({ status: 'empty', maxHeight: 500, opening: true }));
    expect(screen.getByText('Select some text first')).toBeInTheDocument();
  });

  it('keeps the card mounted for a follow-up turn instead of remounting it', async () => {
    let push: (state: ExplainState) => void = () => {};
    api.onExplain.mockImplementation((listener) => {
      push = listener;
      return () => {};
    });
    render(themed(<ExplainApp />));

    await act(async () =>
      push({ status: 'thread', turns: [{ question: 'a', status: 'ready', markdown: 'First.' }], maxHeight: 500, opening: true })
    );
    const card = screen.getByRole('region', { name: 'Explanation' });

    await act(async () =>
      push({
        status: 'thread',
        turns: [
          { question: 'a', status: 'ready', markdown: 'First.' },
          { question: 'b', status: 'loading' },
        ],
        maxHeight: 500,
      })
    );
    expect(screen.getByRole('region', { name: 'Explanation' })).toBe(card);
  });
});

describe('tidyPartial', () => {
  it('drops an opening emphasis or code marker the stream stopped on', () => {
    expect(tidyPartial('Leaves it as is.\n\n**')).toBe('Leaves it as is.');
    expect(tidyPartial('Call it with *')).toBe('Call it with');
    expect(tidyPartial('Use `')).toBe('Use');
  });

  it('leaves complete markdown alone', () => {
    expect(tidyPartial('It **means** x.')).toBe('It **means** x.');
    expect(tidyPartial('Code: `x`')).toBe('Code: `x`');
  });
});
