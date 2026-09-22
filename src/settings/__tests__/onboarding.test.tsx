import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import {
  DEFAULT_SETTINGS,
  type ParleyApi,
  type PermissionStatus,
  type SettingsView,
} from '../../../electron/types';
import { SettingsApp } from '../SettingsApp';
import { Tour } from '../tour/Tour';
import { clampStep, DONE_STEP, stageFor } from '../wizard/stage';

// Embla (behind Mantine's Carousel) consults IntersectionObserver on mount;
// jsdom has none, so the tour would crash before its first slide.
if (!window.IntersectionObserver) {
  window.IntersectionObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  } as unknown as typeof IntersectionObserver;
}

function mockApi(init: { settings?: Partial<SettingsView>; permissions?: PermissionStatus } = {}) {
  let settings: SettingsView = {
    ...DEFAULT_SETTINGS,
    hasApiKey: false,
    hasRewriteKey: false,
    ...init.settings,
  };
  let permissions: PermissionStatus = init.permissions ?? {
    microphone: false,
    accessibility: false,
  };
  const api: ParleyApi = {
    onOrbPhase: () => () => {},
    sendAudio: vi.fn(),
    getSettings: vi.fn(async () => settings),
    updateSettings: vi.fn(async patch => {
      settings = { ...settings, ...patch };
      return settings;
    }),
    setApiKey: vi.fn(async () => ({ ok: true, message: 'Key works' })),
    setRewriteKey: vi.fn(async () => ({ ok: true, message: 'Key works' })),
    getPermissions: vi.fn(async () => permissions),
    requestPermission: vi.fn(async kind => {
      permissions = { ...permissions, [kind]: true };
      return permissions;
    }),
    onExplain: () => () => {},
    reportExplainHeight: vi.fn(),
    copyExplain: vi.fn(),
    dismissExplain: vi.fn(),
  };
  return api;
}

function mount(init: { settings?: Partial<SettingsView>; permissions?: PermissionStatus } = {}) {
  const api = mockApi(init);
  window.parley = api;
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
        <SettingsApp />
      </ThemeProvider>
    </QueryClientProvider>
  );
  return api;
}

describe('onboarding stage', () => {
  it('shows the tour until it has been seen', () => {
    expect(stageFor({ tourSeen: false, onboardingComplete: false })).toBe('tour');
  });

  it('shows the wizard once the tour is seen and setup is unfinished', () => {
    expect(stageFor({ tourSeen: true, onboardingComplete: false })).toBe('wizard');
  });

  it('lands on settings once onboarding completes', () => {
    expect(stageFor({ tourSeen: true, onboardingComplete: true })).toBe('settings');
  });

  it('clamps the persisted step into the wizard', () => {
    expect(clampStep(2)).toBe(2);
    expect(clampStep(DONE_STEP)).toBe(DONE_STEP);
    expect(clampStep(9)).toBe(DONE_STEP);
    expect(clampStep(-1)).toBe(0);
    expect(clampStep(1.5)).toBe(0);
    expect(clampStep(Number.NaN)).toBe(0);
  });
});

describe('onboarding tour', () => {
  beforeEach(() => vi.clearAllMocks());

  it('opens a fresh launch on the first tour slide', async () => {
    mount();
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Skip tour' })).toBeInTheDocument();
  });

  it('skipping the tour lands in the wizard', async () => {
    mount();
    await userEvent.click(await screen.findByRole('button', { name: 'Skip tour' }));
    expect(await screen.findByRole('heading', { name: 'Let Parley hear you' })).toBeInTheDocument();
  });

  it('advances slides with Next', async () => {
    mount();
    await userEvent.click(await screen.findByRole('button', { name: 'Next' }));
    expect(
      await screen.findByRole('heading', { name: 'Say how to change it' })
    ).toBeInTheDocument();
  });

  it('finishes the last slide into the wizard', async () => {
    const onDone = vi.fn();
    window.parley = mockApi();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ThemeProvider defaultTheme="dark" storageKey="test-color-scheme">
          <Tour onDone={onDone} initialSlide={3} />
        </ThemeProvider>
      </QueryClientProvider>
    );
    await userEvent.click(await screen.findByRole('button', { name: 'Set up Parley' }));
    expect(onDone).toHaveBeenCalledOnce();
  });
});

describe('onboarding wizard', () => {
  beforeEach(() => vi.clearAllMocks());

  const wizardAt = (wizardStep: number, extra: Partial<SettingsView> = {}) =>
    mount({
      settings: { tourSeen: true, onboardingComplete: false, wizardStep, ...extra },
      permissions: { microphone: false, accessibility: false },
    });

  it('requests the microphone from step 1', async () => {
    const api = wizardAt(0);
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Microphone' }));
    expect(api.requestPermission).toHaveBeenCalledWith('microphone');
  });

  it('answers a mic grant with the proof, or its error line when capture fails', async () => {
    wizardAt(0);
    // Granting flips the polled permission; jsdom cannot open a mic, so the
    // step lands on the same error line the orb uses in the real app.
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Microphone' }));
    expect(await screen.findByText('Could not access the microphone.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Continue →' })).toBeEnabled();
  });

  it('guides accessibility through System Settings', async () => {
    const api = wizardAt(1, {});
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Accessibility' }));
    expect(api.requestPermission).toHaveBeenCalledWith('accessibility');
  });

  it('tests the Groq key and gates Continue on a stored one', async () => {
    const api = wizardAt(2);
    const keyInput = await screen.findByLabelText('Groq API key');
    expect(screen.getByRole('button', { name: 'Continue →' })).toBeDisabled();
    await userEvent.type(keyInput, 'gsk_abc');
    await userEvent.click(screen.getByRole('button', { name: 'Test and save' }));
    await waitFor(() => expect(api.setApiKey).toHaveBeenCalledWith('gsk_abc'));
    expect(await screen.findByText('Key works')).toBeInTheDocument();
  });

  it('continues past Groq once a key is stored', async () => {
    wizardAt(2, { hasApiKey: true });
    await userEvent.click(await screen.findByRole('button', { name: 'Continue →' }));
    expect(
      await screen.findByRole('heading', { name: 'Add MiniMax? (optional)' })
    ).toBeInTheDocument();
  });

  it('skips MiniMax straight to hotkeys', async () => {
    wizardAt(3);
    await userEvent.click(await screen.findByRole('button', { name: 'Skip for now' }));
    expect(await screen.findByRole('heading', { name: 'Choose your keys' })).toBeInTheDocument();
  });

  it('captures a modifier as the gesture key', async () => {
    const api = wizardAt(4);
    await userEvent.click(await screen.findByRole('button', { name: 'Capture' }));
    fireEvent.keyDown(window, { code: 'MetaRight', key: 'Meta' });
    await waitFor(() =>
      expect(api.updateSettings).toHaveBeenCalledWith({ gestureKey: 'MetaRight' })
    );
  });

  it('rejects a non-modifier while capturing', async () => {
    const api = wizardAt(4);
    await userEvent.click(await screen.findByRole('button', { name: 'Capture' }));
    fireEvent.keyDown(window, { code: 'KeyA', key: 'a' });
    expect(await screen.findByText(/Modifiers only/)).toBeInTheDocument();
    expect(api.updateSettings).not.toHaveBeenCalledWith(
      expect.objectContaining({ gestureKey: expect.anything() })
    );
  });

  it('completes the practice gesture: two taps and a hold', async () => {
    wizardAt(4);
    expect(await screen.findByText(/Tap Right Option 2×, then hold it/)).toBeInTheDocument();
    const down = () => fireEvent.keyDown(window, { code: 'AltRight', key: 'Alt' });
    const up = () => fireEvent.keyUp(window, { code: 'AltRight', key: 'Alt' });
    down();
    up();
    down();
    up();
    down();
    await new Promise(resolve => setTimeout(resolve, 200));
    up();
    expect(await screen.findByText('That’s the gesture ✓')).toBeInTheDocument();
  });

  it('lands practice dictation in the sandbox and finishes to Done', async () => {
    wizardAt(5);
    await userEvent.type(await screen.findByLabelText('Sandbox'), 'hello parley');
    expect(await screen.findByText('It landed')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Finish →' }));
    expect(await screen.findByRole('heading', { name: 'You’re ready' })).toBeInTheDocument();
  });

  it('nudges instead of finishing an empty sandbox', async () => {
    wizardAt(5);
    await userEvent.click(await screen.findByRole('button', { name: 'Finish →' }));
    expect(await screen.findByText('Nothing landed yet')).toBeInTheDocument();
  });

  it('completes from Done into the tabbed settings', async () => {
    wizardAt(6, { hasApiKey: true });
    await userEvent.click(await screen.findByRole('button', { name: 'Open Settings' }));
    expect(await screen.findByRole('tab', { name: 'Gesture' })).toBeInTheDocument();
  });

  it('re-opens the right step from Done when a permission is missing', async () => {
    wizardAt(6, { hasApiKey: true });
    const fixes = await screen.findAllByRole('button', { name: 'Re-open step' });
    await userEvent.click(fixes[0]);
    expect(await screen.findByRole('heading', { name: 'Let Parley hear you' })).toBeInTheDocument();
  });

  it('replays the tour from Done', async () => {
    wizardAt(6, { hasApiKey: true });
    await userEvent.click(await screen.findByRole('button', { name: 'Replay tour' }));
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
  });

  it('resumes a persisted step after a relaunch', async () => {
    wizardAt(4);
    expect(await screen.findByRole('heading', { name: 'Choose your keys' })).toBeInTheDocument();
  });

  it('goes back from step 1 to the tour', async () => {
    wizardAt(0);
    await userEvent.click(await screen.findByRole('button', { name: 'Back' }));
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
  });

  it('replays the tour from General settings', async () => {
    mount({
      settings: { tourSeen: true, onboardingComplete: true, hasApiKey: true, hasRewriteKey: true },
      permissions: { microphone: true, accessibility: true },
    });
    await userEvent.click(await screen.findByRole('tab', { name: 'General' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Replay tour' }));
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
  });
});
