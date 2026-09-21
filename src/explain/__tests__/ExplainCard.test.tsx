import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import type { ExplainState, ParleyApi } from '../../../electron/types';
import { ExplainApp, ExplainCard } from '../ExplainCard';

const api = {
  copyExplain: vi.fn(),
  reportExplainHeight: vi.fn(),
  onExplain: vi.fn(),
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
    show({ status: 'loading', maxHeight: 500 });
    expect(screen.getByRole('status', { name: 'Explaining' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Copy' })).not.toBeInTheDocument();
  });

  it('renders the markdown answer and copies its source', async () => {
    show({ status: 'ready', markdown: 'It **means** x.\n\n- one\n- two', maxHeight: 500 });
    expect(screen.getByText('means').tagName).toBe('STRONG');
    expect(screen.getAllByRole('listitem')).toHaveLength(2);

    await userEvent.click(screen.getByRole('button', { name: 'Copy' }));
    expect(api.copyExplain).toHaveBeenCalledWith('It **means** x.\n\n- one\n- two');
  });

  it('never turns model output into markup or a link', () => {
    show({
      status: 'ready',
      markdown: '<img src=x onerror=steal()> [go](https://evil.example)',
      maxHeight: 500,
    });
    expect(document.querySelector('img')).toBeNull();
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
    expect(screen.getByText('go')).toBeInTheDocument();
  });

  it('shows the question that was asked in place of the command name', () => {
    show({ status: 'loading', question: 'is this thread safe?', maxHeight: 500 });
    expect(screen.getByText('is this thread safe?')).toBeInTheDocument();
    expect(screen.queryByText('Explain')).not.toBeInTheDocument();
  });

  it('says what to do when nothing was selected', () => {
    show({ status: 'empty', maxHeight: 500 });
    expect(screen.getByText('Select some text first')).toBeInTheDocument();
  });

  it('shows an error as an alert', () => {
    show({ status: 'error', message: 'No MiniMax key', maxHeight: 500 });
    expect(screen.getByRole('alert')).toHaveTextContent('No MiniMax key');
  });

  it('caps the card at the height main allows, so only past it does it scroll', () => {
    show({ status: 'loading', maxHeight: 432 });
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

    await act(async () => push({ status: 'empty', maxHeight: 500 }));
    expect(screen.getByText('Select some text first')).toBeInTheDocument();
  });
});
