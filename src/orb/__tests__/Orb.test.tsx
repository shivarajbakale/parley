import { act, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import type { OrbPhasePayload, ParleyApi } from '../../../electron/types';
import { Orb } from '../Orb';

describe('Orb', () => {
  let emit: (payload: OrbPhasePayload) => void;

  beforeEach(() => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(
      null as unknown as CanvasRenderingContext2D
    );
    window.parley = {
      onOrbPhase: (listener: (payload: OrbPhasePayload) => void) => {
        emit = listener;
        return () => {};
      },
      sendAudio: vi.fn(),
    } as unknown as ParleyApi;
  });

  afterEach(() => vi.restoreAllMocks());

  it('shows the error message the main process sends', async () => {
    render(
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <Orb />
      </ThemeProvider>
    );
    await act(async () => emit({ phase: 'error', message: 'No API key' }));
    expect(await screen.findByText('No API key')).toBeInTheDocument();
  });

  it('draws the orb on a 240 px canvas', () => {
    const { container } = render(
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <Orb />
      </ThemeProvider>
    );
    expect(container.querySelector('canvas')!.style.width).toBe('240px');
  });
});
