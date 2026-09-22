import {
  Alert,
  Badge,
  Box,
  Button,
  DataList,
  Group,
  Kbd,
  List,
  RingProgress,
  Stack,
  Text,
  Textarea,
  Title,
} from '@mantine/core';
import { useEffect, useRef, useState } from 'react';
import { animate, useReducedMotion } from 'motion/react';

import { GAP_MAX_MS, HOLD_MIN_MS, TAP_MAX_MS } from '../../../electron/gesture-detector';
import type { GestureKey } from '../../../electron/types';
import { createRecorder } from '../../orb/recorder';
import { OrbCanvas } from '../../orb/OrbCanvas';
import { SILENT_BANDS } from '../../orb/bands';

import { GestureTab } from '../GestureTab';
import { KEY_LABELS } from '../gesture-keys';
import { Pressable, StaggerGroup, StaggerItem } from '../motion';
import shell from '../settings.module.css';
import { ApiKeySection, PermissionRow } from '../SetupTab';
import {
  usePermissions,
  useSetApiKey,
  useSetRewriteKey,
  useSettings,
  useUpdateSettings,
} from '../use-parley';
import { useOnboarding } from './useOnboarding';

/**
 * The six wizard steps plus Done. Each owns its pane: a heading (focused on
 * arrival by the shell), its controls, and its own Back/Continue footer, since
 * what "forward" needs varies per step. All navigation and data ride the
 * existing settings/permissions/key hooks — no step holds wizard state itself.
 */

function StepHead({ children }: { children: React.ReactNode }) {
  return (
    <Title order={1} tabIndex={-1} data-step-heading style={{ outline: 'none' }}>
      {children}
    </Title>
  );
}

function StepFoot({ children }: { children: React.ReactNode }) {
  return (
    <Group justify="space-between" mt="lg">
      {children}
    </Group>
  );
}

/** Footer Back that returns to the tour from step 1, one step otherwise. */
function BackButton() {
  const { back, step, replayTour } = useOnboarding();
  return (
    <Pressable>
      <Button
        variant="default"
        onClick={() => {
          if (step === 0) replayTour();
          else back();
        }}
      >
        Back
      </Button>
    </Pressable>
  );
}

/** Runs `fn` once when `granted` flips false → true, after `delayMs`. Entering
 * the step already granted is not a flip: those users get Continue, not motion. */
function useGrantedAdvance(granted: boolean, delayMs: number, fn: () => void) {
  const fnRef = useRef(fn);
  fnRef.current = fn;
  const wasGranted = useRef(granted);
  useEffect(() => {
    if (granted && !wasGranted.current) {
      wasGranted.current = true;
      const timer = setTimeout(() => fnRef.current(), delayMs);
      return () => clearTimeout(timer);
    }
    wasGranted.current = granted;
  }, [granted, delayMs]);
}

/* --- step 1: microphone --------------------------------------------------- */

const MIC_PROOF_MS = 3000;

export function MicStep() {
  const permissions = usePermissions();
  const { next } = useOnboarding();
  const granted = permissions.data?.microphone ?? false;
  const [recorder] = useState(() => createRecorder());
  const [proofOn, setProofOn] = useState(false);
  const [micError, setMicError] = useState(false);

  useGrantedAdvance(granted, MIC_PROOF_MS, next);

  // The proof: a live orb driven by the real mic while this step is up.
  useEffect(() => {
    if (!granted) return;
    let cancelled = false;
    recorder
      .start()
      .then(() => {
        if (!cancelled) setProofOn(true);
      })
      .catch(() => {
        if (!cancelled) setMicError(true);
      });
    return () => {
      cancelled = true;
      setProofOn(false);
      recorder.discard();
    };
  }, [granted, recorder]);

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Let Parley hear you</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Parley listens only while you hold your key. Grant the mic, then watch the orb move to
              your voice.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <PermissionRow kind="microphone" label="Microphone" granted={granted} />
          </Box>
        </StaggerItem>
        {granted && (
          <StaggerItem>
            <Stack align="center" gap="xs">
              <OrbCanvas
                size={120}
                running={proofOn}
                read={() => ({
                  bands: proofOn ? recorder.bands() : SILENT_BANDS,
                  phase: 'listening',
                })}
              />
              {micError ? (
                <Text size="sm" c="red">
                  Could not access the microphone.
                </Text>
              ) : (
                <Text size="sm" c="dimmed">
                  Speak — the orb moves to your voice.
                </Text>
              )}
            </Stack>
          </StaggerItem>
        )}
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button onClick={next} disabled={!granted}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- step 2: accessibility ------------------------------------------------ */

const A11Y_BEAT_MS = 1200;

export function AccessStep() {
  const permissions = usePermissions();
  const { next } = useOnboarding();
  const granted = permissions.data?.accessibility ?? false;

  useGrantedAdvance(granted, A11Y_BEAT_MS, next);

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Open what Parley needs</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              macOS needs your okay before Parley can see keys and paste. It takes ten seconds in
              System Settings.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <Stack gap="sm">
              <List size="sm" spacing="xs">
                <List.Item>Press the button below</List.Item>
                <List.Item>Toggle Parley on in System Settings</List.Item>
                <List.Item>Come back — this step finishes itself</List.Item>
              </List>
              <PermissionRow kind="accessibility" label="Accessibility" granted={granted} />
            </Stack>
          </Box>
        </StaggerItem>
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button onClick={next} disabled={!granted}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- steps 3–4: API keys -------------------------------------------------- */

export function GroqKeyStep() {
  const settings = useSettings();
  const setApiKey = useSetApiKey();
  const { next } = useOnboarding();
  const hasKey = settings.data?.hasApiKey ?? false;

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Add your Groq key</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Groq turns your speech into text. The key is tested before it is stored, and never
              shown again.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <ApiKeySection
              label="Groq API key"
              placeholder="gsk_…"
              purpose="Transcribes what you say."
              submitLabel="Test and save"
              hasApiKey={hasKey}
              setApiKey={setApiKey}
            />
          </Box>
        </StaggerItem>
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button onClick={next} disabled={!hasKey}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

export function MinimaxStep() {
  const settings = useSettings();
  const setRewriteKey = useSetRewriteKey();
  const { next } = useOnboarding();
  const hasKey = settings.data?.hasRewriteKey ?? false;

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Add MiniMax? (optional)</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Only voice edit and Explain need it. Skip now and add it later in Setup.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <ApiKeySection
              label="MiniMax API key"
              placeholder="Optional"
              purpose="Only for voice edit, which rewrites the text in a field."
              submitLabel="Test and save MiniMax key"
              hasApiKey={hasKey}
              setApiKey={setRewriteKey}
            />
          </Box>
        </StaggerItem>
        <StepFoot>
          <BackButton />
          <Group gap="sm">
            <Pressable>
              <Button variant="subtle" onClick={next}>
                Skip for now
              </Button>
            </Pressable>
            <Pressable>
              <Button onClick={next} disabled={!hasKey}>
                Continue →
              </Button>
            </Pressable>
          </Group>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- step 5: hotkeys ------------------------------------------------------ */

const CODE_TO_KEY: Record<string, GestureKey> = {
  AltLeft: 'Alt',
  AltRight: 'AltRight',
  ControlLeft: 'Ctrl',
  ControlRight: 'CtrlRight',
  ShiftLeft: 'Shift',
  ShiftRight: 'ShiftRight',
  MetaLeft: 'Meta',
  MetaRight: 'MetaRight',
};

function PracticeMeter({ gestureKey, tapCount }: { gestureKey: GestureKey; tapCount: number }) {
  const reduceMotion = useReducedMotion();
  const [taps, setTaps] = useState(0);
  const [holding, setHolding] = useState(false);
  const [held, setHeld] = useState(false);
  const [holdValue, setHoldValue] = useState(0);
  const downAt = useRef<number | null>(null);
  const gapTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const state = useRef({ taps: 0, holding: false });
  state.current.taps = taps;

  useEffect(() => {
    const reset = () => {
      setTaps(0);
      setHolding(false);
      setHeld(false);
      setHoldValue(0);
      state.current = { taps: 0, holding: false };
    };

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.repeat) return;
      const key = CODE_TO_KEY[event.code];
      if (!key || key !== gestureKey) return;
      event.preventDefault();
      if (gapTimer.current) clearTimeout(gapTimer.current);
      downAt.current = performance.now();
      if (state.current.taps === tapCount - 1) {
        state.current.holding = true;
        setHolding(true);
        // Reduced motion — or no frame loop at all (jsdom) — completes at once.
        if (reduceMotion || typeof requestAnimationFrame === 'undefined') {
          setHoldValue(100);
        } else {
          const controls = animate(0, 100, {
            duration: HOLD_MIN_MS / 1000,
            ease: 'linear',
            onUpdate: value => setHoldValue(value),
          });
          gapTimer.current = setTimeout(() => controls.stop(), HOLD_MIN_MS + 50);
        }
      }
    };

    const onKeyUp = (event: KeyboardEvent) => {
      const key = CODE_TO_KEY[event.code];
      if (!key || key !== gestureKey || downAt.current === null) return;
      event.preventDefault();
      const heldFor = performance.now() - downAt.current;
      downAt.current = null;
      if (state.current.holding) {
        state.current.holding = false;
        setHolding(false);
        if (heldFor >= HOLD_MIN_MS) {
          setHeld(true);
          setHoldValue(100);
        } else {
          setHoldValue(0);
          reset();
        }
        return;
      }
      if (heldFor >= TAP_MAX_MS) {
        reset();
        return;
      }
      const next = state.current.taps + 1;
      state.current.taps = next;
      setTaps(next);
      if (gapTimer.current) clearTimeout(gapTimer.current);
      gapTimer.current = setTimeout(reset, GAP_MAX_MS);
    };

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      if (gapTimer.current) clearTimeout(gapTimer.current);
    };
  }, [gestureKey, tapCount, reduceMotion]);

  return (
    <Stack gap="xs" align="center">
      <Group
        gap="xs"
        aria-label={`Practice: ${taps} of ${tapCount - 1} taps, hold ${held ? 'done' : 'pending'}`}
      >
        {Array.from({ length: tapCount - 1 }, (_, i) => (
          <Box
            key={i}
            w={10}
            h={10}
            style={{
              borderRadius: 999,
              background: i < taps ? 'var(--app-aurora-core)' : 'var(--app-glass-hover)',
              border: '1px solid var(--app-glass-border)',
            }}
          />
        ))}
        <RingProgress
          size={44}
          thickness={5}
          sections={[{ value: holding || held ? holdValue : 0, color: 'teal' }]}
          label={
            <Text size="xs" ta="center" c={held ? 'teal' : 'dimmed'}>
              {held ? '✓' : 'hold'}
            </Text>
          }
        />
      </Group>
      <Text size="xs" c={held ? 'teal' : 'dimmed'} aria-live="polite">
        {held
          ? 'That’s the gesture ✓'
          : `Tap ${KEY_LABELS[gestureKey]} ${tapCount - 1}×, then hold it`}
      </Text>
    </Stack>
  );
}

export function HotkeysStep() {
  const settings = useSettings();
  const update = useUpdateSettings();
  const { next } = useOnboarding();
  const [capturing, setCapturing] = useState(false);
  const [captureError, setCaptureError] = useState(false);
  const data = settings.data;

  // While armed, the next modifier pressed anywhere in this window becomes the
  // gesture key. Escape stands down without changing anything.
  useEffect(() => {
    if (!capturing) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setCapturing(false);
        return;
      }
      const key = CODE_TO_KEY[event.code];
      if (!key) {
        setCaptureError(true);
        return;
      }
      event.preventDefault();
      setCaptureError(false);
      setCapturing(false);
      update.mutate({ gestureKey: key });
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [capturing, update]);

  if (!data) return null;

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Choose your keys</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Tap, tap, hold the last press to talk. Capture your key, tune the rest, then try the
              gesture below.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <Stack gap="sm">
              <Group justify="space-between" wrap="nowrap">
                <Group gap="xs">
                  <Kbd>{KEY_LABELS[data.gestureKey]}</Kbd>
                  <Text size="sm" c="dimmed">
                    {capturing ? 'Press a modifier…' : 'your gesture key'}
                  </Text>
                </Group>
                <Pressable>
                  <Button
                    size="xs"
                    variant={capturing ? 'filled' : 'light'}
                    onClick={() => {
                      setCaptureError(false);
                      setCapturing(armed => !armed);
                    }}
                  >
                    {capturing ? 'Listening…' : 'Capture'}
                  </Button>
                </Pressable>
              </Group>
              {captureError && (
                <Text size="xs" c="red" role="alert">
                  Modifiers only — try Option, Control, Shift or Command.
                </Text>
              )}
              <PracticeMeter gestureKey={data.gestureKey} tapCount={data.tapCount} />
            </Stack>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <GestureTab bare settings={data} onChange={patch => update.mutate(patch)} />
        </StaggerItem>
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button onClick={next}>Continue →</Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- step 6: practice ----------------------------------------------------- */

export function PracticeStep() {
  const { next } = useOnboarding();
  const [landed, setLanded] = useState(false);
  const [nudge, setNudge] = useState(false);

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Say your first sentence</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              A real dictation — hold your key, speak, release. Keep this box focused: your words
              land here.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Textarea
            label="Sandbox"
            description="Speak now — nothing leaves this box."
            placeholder="“ …speak now… ”"
            rows={3}
            autoFocus
            onChange={event => {
              if (event.currentTarget.value.trim()) {
                setLanded(true);
                setNudge(false);
              }
            }}
          />
        </StaggerItem>
        <StaggerItem>
          <List size="sm" spacing="xs">
            <List.Item>Hold your gesture key</List.Item>
            <List.Item>Speak a sentence</List.Item>
            <List.Item>Release — the text appears above</List.Item>
          </List>
        </StaggerItem>
        {landed && (
          <Alert color="teal" variant="light" title="It landed">
            That’s dictation. Finish whenever you’re ready.
          </Alert>
        )}
        {nudge && !landed && (
          <Alert color="yellow" variant="light" title="Nothing landed yet" role="alert">
            Hold a little longer — past a short tap — then press Finish.
          </Alert>
        )}
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button
              onClick={() => {
                if (!landed) {
                  setNudge(true);
                  return;
                }
                next();
              }}
            >
              Finish →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- done ----------------------------------------------------------------- */

function SummaryRow({
  label,
  ok,
  value,
  fix,
}: {
  label: string;
  ok: boolean;
  value: string;
  fix?: { label: string; onFix(): void };
}) {
  return (
    <DataList.Item>
      <DataList.ItemLabel>{label}</DataList.ItemLabel>
      <DataList.ItemValue>
        <Group gap="xs" justify="flex-end">
          <Badge color={ok ? 'teal' : 'yellow'} variant="light">
            {value}
          </Badge>
          {fix && (
            <Button size="compact-xs" variant="subtle" onClick={fix.onFix}>
              {fix.label}
            </Button>
          )}
        </Group>
      </DataList.ItemValue>
    </DataList.Item>
  );
}

export function DoneStep() {
  const settings = useSettings();
  const permissions = usePermissions();
  const { complete, goTo } = useOnboarding();
  const data = settings.data;
  const mic = permissions.data?.microphone ?? false;
  const a11y = permissions.data?.accessibility ?? false;

  if (!data) return null;

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>You’re ready</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Parley is listening everywhere. Here’s what got configured.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <DataList withDivider labelWidth={130}>
              <SummaryRow
                label="Microphone"
                ok={mic}
                value={mic ? 'Granted' : 'Missing'}
                fix={mic ? undefined : { label: 'Re-open step', onFix: () => goTo(0) }}
              />
              <SummaryRow
                label="Accessibility"
                ok={a11y}
                value={a11y ? 'Granted' : 'Missing'}
                fix={a11y ? undefined : { label: 'Re-open step', onFix: () => goTo(1) }}
              />
              <SummaryRow
                label="Groq key"
                ok={data.hasApiKey}
                value={data.hasApiKey ? 'Stored' : 'Missing'}
                fix={data.hasApiKey ? undefined : { label: 'Re-open step', onFix: () => goTo(2) }}
              />
              <SummaryRow
                label="Gesture"
                ok
                value={`${KEY_LABELS[data.gestureKey]} ×${data.tapCount}`}
              />
              <SummaryRow
                label="MiniMax"
                ok={data.hasRewriteKey}
                value={data.hasRewriteKey ? 'Stored' : 'Skipped'}
              />
            </DataList>
          </Box>
        </StaggerItem>
        <StepFoot>
          <ReplayTourButton />
          <Pressable>
            <Button size="md" className={shell.primary} onClick={complete}>
              Open Settings
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

export function ReplayTourButton() {
  const { replayTour } = useOnboarding();
  return (
    <Pressable>
      <Button variant="subtle" onClick={replayTour}>
        Replay tour
      </Button>
    </Pressable>
  );
}
