import { fireEvent, render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import { DEFAULT_SETTINGS, type ParleyApi } from '../../../electron/types';
import { OrbPulseContext } from '../wizard/orb-pulse';
import { TrainerStep } from '../wizard/steps';

describe('trainer pulses the ring orb', () => {
  it('kicks once per real press of the gesture key, not on auto-repeat or other keys', async () => {
    window.parley = {
      getSettings: vi.fn(async () => ({
        ...DEFAULT_SETTINGS,
        hasApiKey: true,
        hasRewriteKey: false,
        wordsDictated: 0,
      })),
    } as unknown as ParleyApi;
    const pulse = vi.fn();
    render(
      <QueryClientProvider client={new QueryClient()}>
        <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
          <OrbPulseContext.Provider value={pulse}>
            <TrainerStep />
          </OrbPulseContext.Provider>
        </ThemeProvider>
      </QueryClientProvider>
    );
    await screen.findByRole('heading', { name: 'Learn the gesture' });

    fireEvent.keyDown(window, { code: 'AltRight', key: 'Alt' });
    fireEvent.keyDown(window, { code: 'AltRight', key: 'Alt', repeat: true });
    fireEvent.keyUp(window, { code: 'AltRight', key: 'Alt' });
    fireEvent.keyDown(window, { code: 'KeyA', key: 'a' });
    expect(pulse).toHaveBeenCalledTimes(1);
  });
});
