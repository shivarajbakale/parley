import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ThemeProvider } from '@/components/theme-provider';

import {
  DEFAULT_SETTINGS,
  OFFLINE_AGENT_SUMMARY,
  type ParleyApi,
  type PermissionStatus,
  type ServerStatus,
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

const RUNNING: ServerStatus = {
  reachable: true,
  url: 'http://localhost:3100',
  keys: { groq: true, deepgram: false, minimax: true },
};

function mockApi(
  init: { settings?: Partial<SettingsView>; permissions?: PermissionStatus; server?: ServerStatus } = {}
) {
  let settings: SettingsView = {
    ...DEFAULT_SETTINGS,
    wordsDictated: 0,
    hasSyncToken: false,
    syncLastAt: 0,
    syncLastError: '',
    agent: OFFLINE_AGENT_SUMMARY,
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
    setTranscriptionProvider: vi.fn(async transcriptionProvider => {
      settings = { ...settings, transcriptionProvider };
      return settings;
    }),
    serverStatus: vi.fn(async () => init.server ?? RUNNING),
    setAgentUrl: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    testAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    restartAgent: vi.fn(async () => ({ ok: true, message: 'Agent works', mcpServers: [] })),
    decideApproval: vi.fn(async () => true),
    agentStatus: vi.fn(async () => OFFLINE_AGENT_SUMMARY),
    signInSync: vi.fn(),
    signOutSync: vi.fn(),
    syncNow: vi.fn(),
    getPermissions: vi.fn(async () => permissions),
    requestPermission: vi.fn(async kind => {
      permissions = { ...permissions, [kind]: true };
      return permissions;
    }),
    onExplain: () => () => {},
    reportExplainHeight: vi.fn(),
    copyExplain: vi.fn(),
    dismissExplain: vi.fn(),
    openExternal: vi.fn(),
    onSessionBlocked: vi.fn(() => () => {}),
    takeBlockedReason: vi.fn(async () => null),
  };
  return api;
}

function mount(init: Parameters<typeof mockApi>[0] = {}) {
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
  it('opens a fresh install on the first-run flow, not the tour', () => {
    expect(stageFor({ tourSeen: false, onboardingComplete: false })).toBe('wizard');
  });

  it('shows the tour only as a replay once onboarding is complete', () => {
    expect(stageFor({ tourSeen: false, onboardingComplete: true })).toBe('tour');
  });

  it('lands on settings once onboarding completes', () => {
    expect(stageFor({ tourSeen: true, onboardingComplete: true })).toBe('settings');
  });

  it('clamps the persisted step into the flow', () => {
    expect(clampStep(2)).toBe(2);
    expect(clampStep(DONE_STEP)).toBe(DONE_STEP);
    expect(clampStep(9)).toBe(DONE_STEP);
    expect(clampStep(-1)).toBe(0);
    expect(clampStep(1.5)).toBe(0);
    expect(clampStep(Number.NaN)).toBe(0);
  });
});

describe('onboarding tour (replay)', () => {
  beforeEach(() => vi.clearAllMocks());

  const replaying = () =>
    mount({
      settings: { tourSeen: false, onboardingComplete: true },
      permissions: { microphone: true, accessibility: true },
    });

  it('opens a replay on the first tour slide', async () => {
    replaying();
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Skip tour' })).toBeInTheDocument();
  });

  it('skipping the replay returns to settings', async () => {
    replaying();
    await userEvent.click(await screen.findByRole('button', { name: 'Skip tour' }));
    expect(await screen.findByRole('tab', { name: 'Gesture' })).toBeInTheDocument();
  });

  it('advances slides with Next', async () => {
    replaying();
    await userEvent.click(await screen.findByRole('button', { name: 'Next' }));
    expect(
      await screen.findByRole('heading', { name: 'Say how to change it' })
    ).toBeInTheDocument();
  });

  it('closes from the last slide with Done', async () => {
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
    await userEvent.click(await screen.findByRole('button', { name: 'Done' }));
    expect(onDone).toHaveBeenCalledOnce();
  });
});

describe('first-run flow', () => {
  beforeEach(() => vi.clearAllMocks());

  const wizardAt = (wizardStep: number, extra: Partial<SettingsView> = {}) =>
    mount({
      settings: { onboardingComplete: false, wizardStep, ...extra },
      permissions: { microphone: false, accessibility: false },
    });

  it('opens a fresh launch on Welcome with the three modes', async () => {
    mount();
    expect(await screen.findByRole('heading', { name: 'Talk to any text field' })).toBeInTheDocument();
    expect(screen.getByText('Voice edit')).toBeInTheDocument();
    expect(screen.getByText('Explain')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Back' })).not.toBeInTheDocument();
  });

  it('gets started into the microphone screen', async () => {
    wizardAt(0);
    await userEvent.click(await screen.findByRole('button', { name: 'Get started →' }));
    expect(await screen.findByRole('heading', { name: 'Let Parley hear you' })).toBeInTheDocument();
  });

  it('requests the microphone', async () => {
    const api = wizardAt(1);
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Microphone' }));
    expect(api.requestPermission).toHaveBeenCalledWith('microphone');
  });

  it('answers a mic grant with the proof, or its error line when capture fails', async () => {
    wizardAt(1);
    // Granting flips the polled permission; jsdom cannot open a mic, so the
    // step lands on the same error line the orb uses in the real app.
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Microphone' }));
    expect(await screen.findByText('Could not access the microphone.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Continue →' })).toBeEnabled();
  });

  it('goes back from the microphone to Welcome', async () => {
    wizardAt(1);
    await userEvent.click(await screen.findByRole('button', { name: 'Back' }));
    expect(await screen.findByRole('heading', { name: 'Talk to any text field' })).toBeInTheDocument();
  });

  it('guides accessibility through System Settings', async () => {
    const api = wizardAt(2);
    await userEvent.click(await screen.findByRole('button', { name: 'Grant Accessibility' }));
    expect(api.requestPermission).toHaveBeenCalledWith('accessibility');
  });

  it('checks the Parley server for the Groq key instead of asking for one', async () => {
    wizardAt(3);
    expect(
      await screen.findByRole('heading', { name: 'Transcription runs on your Parley server' })
    ).toBeInTheDocument();
    expect(await screen.findByText('Running')).toBeInTheDocument();
    expect(screen.getByText('On the server')).toBeInTheDocument();
    expect(screen.queryByLabelText(/API key/)).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Continue →' })).toBeEnabled();
  });

  it('says how to start a server that is down, and still lets setup go on', async () => {
    mount({
      settings: { onboardingComplete: false, wizardStep: 3 },
      permissions: { microphone: true, accessibility: true },
      server: { reachable: false, url: 'http://localhost:3100', keys: null },
    });
    expect(await screen.findByText('Not running')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Start it with make api');
    expect(screen.getByRole('button', { name: 'Continue →' })).toBeEnabled();
  });

  it('continues past transcription straight to the trainer, with no MiniMax screen', async () => {
    wizardAt(3);
    await userEvent.click(await screen.findByRole('button', { name: 'Continue →' }));
    expect(await screen.findByRole('heading', { name: 'Learn the gesture' })).toBeInTheDocument();
    expect(screen.queryByLabelText('MiniMax API key')).not.toBeInTheDocument();
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

  it('completes the gesture in the trainer: two taps and a hold', async () => {
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

  it('names a tap held too long', async () => {
    wizardAt(4);
    await screen.findByText(/Tap Right Option 2×, then hold it/);
    fireEvent.keyDown(window, { code: 'AltRight', key: 'Alt' });
    await new Promise(resolve => setTimeout(resolve, 280));
    fireEvent.keyUp(window, { code: 'AltRight', key: 'Alt' });
    expect(await screen.findByText(/That tap was a hold/)).toBeInTheDocument();
  });

  it('keeps the other keys behind More keys', async () => {
    wizardAt(4);
    const toggle = await screen.findByRole('button', { name: /More keys/ });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await userEvent.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    const inputs = await screen.findAllByLabelText('Voice edit key');
    expect(inputs.find(node => node.tagName === 'INPUT')).toBeDefined();
  });

  it('lands practice dictation in the sandbox and finishes to the finale', async () => {
    wizardAt(5);
    await userEvent.type(await screen.findByLabelText('Sandbox'), 'hello parley');
    expect(await screen.findByText('It landed')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Finish →' }));
    expect(
      await screen.findByRole('heading', { name: 'Parley lives in your menu bar' })
    ).toBeInTheDocument();
  });

  it('nudges instead of finishing an empty sandbox', async () => {
    wizardAt(5);
    await userEvent.click(await screen.findByRole('button', { name: 'Finish →' }));
    expect(await screen.findByText('Nothing landed yet')).toBeInTheDocument();
  });

  it('starts using Parley from the finale, marking the tour seen', async () => {
    const api = wizardAt(6);
    await userEvent.click(await screen.findByRole('button', { name: 'Start using Parley' }));
    expect(await screen.findByRole('tab', { name: 'Gesture' })).toBeInTheDocument();
    expect(api.updateSettings).toHaveBeenCalledWith({ onboardingComplete: true, tourSeen: true });
  });

  it('lists only what is missing on the finale, each with a fix', async () => {
    wizardAt(6);
    const fixes = await screen.findAllByRole('button', { name: 'Re-open step' });
    expect(fixes).toHaveLength(2);
    expect(screen.queryByText('Transcription')).not.toBeInTheDocument();
    await userEvent.click(fixes[0]);
    expect(await screen.findByRole('heading', { name: 'Let Parley hear you' })).toBeInTheDocument();
  });

  it('shows no missing list when everything is set', async () => {
    mount({
      settings: { onboardingComplete: false, wizardStep: 6 },
      permissions: { microphone: true, accessibility: true },
    });
    await screen.findByRole('heading', { name: 'Parley lives in your menu bar' });
    expect(screen.queryByText('Still to do')).not.toBeInTheDocument();
  });

  it('takes the tour from the finale', async () => {
    wizardAt(6);
    await userEvent.click(await screen.findByRole('button', { name: 'Take the tour' }));
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
  });

  it('resumes a persisted step after a relaunch', async () => {
    wizardAt(4);
    expect(await screen.findByRole('heading', { name: 'Learn the gesture' })).toBeInTheDocument();
  });

  it('replays the tour from General settings', async () => {
    mount({
      settings: { tourSeen: true, onboardingComplete: true },
      permissions: { microphone: true, accessibility: true },
    });
    await userEvent.click(await screen.findByRole('tab', { name: 'General' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Replay tour' }));
    expect(
      await screen.findByRole('heading', { name: 'Hold to talk, release to paste' })
    ).toBeInTheDocument();
  });
});
