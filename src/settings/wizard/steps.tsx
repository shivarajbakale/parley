import {
  Alert,
  Anchor,
  Badge,
  Box,
  Button,
  Collapse,
  ColorSwatch,
  DataList,
  Group,
  Kbd,
  List,
  Stack,
  Text,
  Textarea,
  Title,
} from '@mantine/core';
import { useEffect, useReducer, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';

import { SPRING } from '@/lib/motion';

import { GAP_MAX_MS, HOLD_MIN_MS } from '../../../electron/gesture-detector';
import type { GestureKey, OrbPhase } from '../../../electron/types';
import { createRecorder } from '../../orb/recorder';
import { OrbCanvas } from '../../orb/OrbCanvas';
import { SILENT_BANDS } from '../../orb/bands';

import { GestureTab } from '../GestureTab';
import { KEY_GLYPHS, KEY_LABELS } from '../gesture-keys';
import { Pressable, StaggerGroup, StaggerItem } from '../motion';
import shell from '../settings.module.css';
import { ApiKeySection, PermissionRow } from '../SetupTab';
import { usePermissions, useSetApiKey, useSettings, useUpdateSettings } from '../use-parley';

import classes from './Trainer.module.css';
import { MISS_COPY, TRAINER_START, trainerStep, type TrainerState } from './trainer';
import { useOnboarding } from './useOnboarding';

/**
 * The six first-run screens plus the finale. Each owns its pane: a heading
 * (focused on arrival by the shell), its controls, and its own footer, since
 * what "forward" needs varies per screen. All navigation and data ride the
 * existing settings/permissions/key hooks — no screen holds flow state itself.
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

function BackButton() {
  const { back } = useOnboarding();
  return (
    <Pressable>
      <Button variant="default" onClick={back}>
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

const readIdle = () => ({ bands: SILENT_BANDS, phase: 'listening' as OrbPhase });

/* --- 1: welcome ----------------------------------------------------------- */

/** The three modes in the colours the orb wears for each. */
const MODES = [
  { name: 'Dictate', color: 'var(--app-aurora-core)', copy: 'Hold your key, speak, release. Words land at the cursor.' },
  { name: 'Voice edit', color: 'var(--app-edit-core)', copy: 'Say how to change the text in a field.' },
  { name: 'Explain', color: 'var(--app-explain-core)', copy: 'Select text anywhere and ask about it.' },
];

export function WelcomeStep() {
  const { next } = useOnboarding();

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box ta="center">
            <Text size="xs" fw={600} tt="uppercase" c="dimmed" style={{ letterSpacing: '0.08em' }}>
              Welcome to Parley
            </Text>
            <StepHead>Talk to any text field</StepHead>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <Stack gap="sm">
              {MODES.map(mode => (
                <Group key={mode.name} gap="sm" wrap="nowrap" align="flex-start">
                  <ColorSwatch color={mode.color} size={14} withShadow={false} mt={3} />
                  <Box style={{ minWidth: 0 }}>
                    <Text size="sm" fw={600}>
                      {mode.name}
                    </Text>
                    <Text size="sm" c="dimmed">
                      {mode.copy}
                    </Text>
                  </Box>
                </Group>
              ))}
            </Stack>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Text size="xs" c="dimmed" ta="center">
            The mic is live only while you hold, and nothing is stored. Setup takes about two
            minutes.
          </Text>
        </StaggerItem>
        <Group justify="center" mt="sm">
          <Pressable>
            <Button size="md" className={shell.primary} onClick={next}>
              Get started →
            </Button>
          </Pressable>
        </Group>
      </Stack>
    </StaggerGroup>
  );
}

/* --- 2: microphone -------------------------------------------------------- */

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
            <Button className={shell.primary} onClick={next} disabled={!granted}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- 3: accessibility ----------------------------------------------------- */

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
            <Button className={shell.primary} onClick={next} disabled={!granted}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- 4: transcription ----------------------------------------------------- */

export function TranscriptionStep() {
  const settings = useSettings();
  const setApiKey = useSetApiKey();
  const { next } = useOnboarding();
  const hasKey = settings.data?.hasApiKey ?? false;

  return (
    <StaggerGroup>
      <Stack gap="md">
        <StaggerItem>
          <Box>
            <StepHead>Connect transcription</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Groq’s Whisper turns your voice into text. Paste a Groq API key — it is tested before
              it is stored, and never shown again.{' '}
              <Anchor href="https://console.groq.com/keys" target="_blank" size="sm">
                Get a free key
              </Anchor>
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
            <Button className={shell.primary} onClick={next} disabled={!hasKey}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- 5: gesture trainer --------------------------------------------------- */

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

function capState(state: TrainerState, index: number, tapCount: number) {
  if (state.phase === 'done') return 'done';
  if (index < state.taps) return 'lit';
  if (index === tapCount - 1 && state.phase === 'holding') return 'holding';
  if (index === state.taps && state.downAt !== null) return 'lit';
  return undefined;
}

function trainerLine(state: TrainerState, gestureKey: GestureKey, tapCount: number) {
  if (state.phase === 'done') return 'That’s the gesture ✓';
  if (state.phase === 'holding') return 'Keep holding…';
  if (state.miss) return MISS_COPY[state.miss];
  if (state.taps > 0) return `${state.taps} of ${tapCount - 1} taps — keep going`;
  return `Tap ${KEY_LABELS[gestureKey]} ${tapCount - 1}×, then hold it`;
}

/**
 * One key cap per press. The last one fills while it is held; a try that
 * resets says why, in the real detector's terms. Keyed on key and press count
 * by its parent, so a settings change starts it fresh.
 */
function GestureTrainer({
  gestureKey,
  tapCount,
  paused,
}: {
  gestureKey: GestureKey;
  tapCount: number;
  /** While the key is being captured, presses belong to the capture. */
  paused: boolean;
}) {
  const [state, dispatch] = useReducer(
    (current: TrainerState, event: Parameters<typeof trainerStep>[1]) =>
      trainerStep(current, event, tapCount),
    TRAINER_START
  );

  useEffect(() => {
    if (paused) return;
    const matches = (event: KeyboardEvent) => CODE_TO_KEY[event.code] === gestureKey;
    const onKeyDown = (event: KeyboardEvent) => {
      if (!matches(event)) return;
      event.preventDefault();
      dispatch({ type: 'down', at: performance.now() });
    };
    const onKeyUp = (event: KeyboardEvent) => {
      if (!matches(event)) return;
      event.preventDefault();
      dispatch({ type: 'up', at: performance.now() });
    };
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
    };
  }, [gestureKey, paused]);

  // The two moments that pass with no key event: the hold reaching its
  // minimum, and the gap after a tap running out.
  useEffect(() => {
    let wait: number | null = null;
    if (state.phase === 'holding' && state.downAt !== null) wait = HOLD_MIN_MS;
    else if (state.phase === 'tapping' && state.downAt === null) wait = GAP_MAX_MS + 1;
    if (wait === null) return;
    const timer = setTimeout(() => dispatch({ type: 'tick', at: performance.now() }), wait);
    return () => clearTimeout(timer);
  }, [state]);

  const done = state.phase === 'done';

  return (
    <Stack gap="sm" align="center">
      <Box
        className={classes.caps}
        aria-hidden="true"
        style={{ '--hold-ms': `${HOLD_MIN_MS}ms` } as React.CSSProperties}
      >
        {Array.from({ length: tapCount }, (_, index) => (
          <Kbd key={index} className={classes.cap} data-state={capState(state, index, tapCount)}>
            {KEY_GLYPHS[gestureKey]}
            <span className={classes.label}>{index < tapCount - 1 ? 'tap' : 'hold'}</span>
          </Kbd>
        ))}
      </Box>
      <Text
        size="sm"
        c={done ? 'teal' : state.miss && state.phase === 'idle' ? 'yellow' : 'dimmed'}
        aria-live="polite"
        ta="center"
      >
        {trainerLine(state, gestureKey, tapCount)}
      </Text>
    </Stack>
  );
}

export function TrainerStep() {
  const settings = useSettings();
  const update = useUpdateSettings();
  const { next } = useOnboarding();
  const [capturing, setCapturing] = useState(false);
  const [captureError, setCaptureError] = useState(false);
  const [moreKeys, setMoreKeys] = useState(false);
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
            <StepHead>Learn the gesture</StepHead>
            <Text size="sm" c="dimmed" mt={4}>
              Quick taps, then hold the last press to talk. Try it here — nothing is recorded.
            </Text>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Box className={shell.glass} p="md">
            <Stack gap="md">
              <GestureTrainer
                key={`${data.gestureKey}-${data.tapCount}`}
                gestureKey={data.gestureKey}
                tapCount={data.tapCount}
                paused={capturing}
              />
              <Group justify="space-between" wrap="nowrap">
                <Group gap="xs" wrap="nowrap" style={{ minWidth: 0 }}>
                  <Kbd>{KEY_LABELS[data.gestureKey]}</Kbd>
                  <Text size="sm" c="dimmed" truncate>
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
            </Stack>
          </Box>
        </StaggerItem>
        <StaggerItem>
          <Button
            variant="subtle"
            size="xs"
            aria-expanded={moreKeys}
            onClick={() => setMoreKeys(open => !open)}
          >
            {moreKeys ? 'Fewer options' : 'More keys: voice edit, Explain, presses'}
          </Button>
          <Collapse expanded={moreKeys}>
            <Box mt="sm">
              <GestureTab bare settings={data} onChange={patch => update.mutate(patch)} />
            </Box>
          </Collapse>
        </StaggerItem>
        <StepFoot>
          <BackButton />
          <Pressable>
            <Button className={shell.primary} onClick={next}>
              Continue →
            </Button>
          </Pressable>
        </StepFoot>
      </Stack>
    </StaggerGroup>
  );
}

/* --- 6: first words ------------------------------------------------------- */

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
              className={shell.primary}
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

/* --- finale --------------------------------------------------------------- */

/** How long the orb rests in the middle before it flies to the menu bar. */
const FINALE_BEAT_MS = 700;
const FLYING_ORB = 160;
const DOCKED_ORB = 60;

/**
 * The orb, centred on whatever box holds it. Both the middle of the pane and
 * the menu bar slot render one with the same layoutId, so switching which of
 * them holds it is the flight.
 */
function FinaleOrb({ size }: { size: number }) {
  // The orb's body sits below its canvas centre; lift by that much.
  const lift = Math.round(size * 0.165);
  return (
    <motion.div
      layoutId="finale-orb"
      transition={SPRING}
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width: size,
        height: size,
        marginLeft: -size / 2,
        marginTop: -size / 2 - lift,
        pointerEvents: 'none',
      }}
    >
      <OrbCanvas size={size} running read={readIdle} />
    </motion.div>
  );
}

function MissingRow({ label, value, onFix }: { label: string; value: string; onFix(): void }) {
  return (
    <DataList.Item>
      <DataList.ItemLabel>{label}</DataList.ItemLabel>
      <DataList.ItemValue>
        <Group gap="xs" justify="flex-end">
          <Badge color="yellow" variant="light">
            {value}
          </Badge>
          <Button size="compact-xs" variant="subtle" onClick={onFix}>
            Re-open step
          </Button>
        </Group>
      </DataList.ItemValue>
    </DataList.Item>
  );
}

export function FinaleStep() {
  const settings = useSettings();
  const permissions = usePermissions();
  const { complete, goTo, replayTour } = useOnboarding();
  const reduced = useReducedMotion();
  const [landed, setLanded] = useState(!!reduced);
  const data = settings.data;

  useEffect(() => {
    if (landed) return;
    const timer = setTimeout(() => setLanded(true), FINALE_BEAT_MS);
    return () => clearTimeout(timer);
  }, [landed]);

  if (!data) return null;

  const mic = permissions.data?.microphone ?? false;
  const a11y = permissions.data?.accessibility ?? false;
  const missing: { label: string; value: string; step: number }[] = [];
  if (!mic) missing.push({ label: 'Microphone', value: 'Missing', step: 1 });
  if (!a11y) missing.push({ label: 'Accessibility', value: 'Missing', step: 2 });
  if (!data.hasApiKey) missing.push({ label: 'Transcription', value: 'No key', step: 3 });

  return (
    <Stack gap="md">
      <Box className={shell.glass} style={{ borderRadius: 'var(--mantine-radius-md)' }}>
        <Group className={classes.menubar} justify="flex-end" gap="md" wrap="nowrap">
          <Box className={classes.slot} aria-hidden="true">
            {landed && <FinaleOrb size={DOCKED_ORB} />}
          </Box>
          <Text size="xs" c="dimmed">
            Wi‑Fi
          </Text>
          <Text size="xs" c="dimmed">
            9:41
          </Text>
        </Group>
      </Box>
      {/* The launch pad closes up once the orb has left, so the copy rises
          under the menu bar instead of leaving an empty band behind. */}
      <motion.div
        aria-hidden="true"
        initial={false}
        animate={{ height: landed ? 0 : FLYING_ORB - 48 }}
        transition={SPRING}
        style={{ position: 'relative' }}
      >
        {!landed && <FinaleOrb size={FLYING_ORB} />}
      </motion.div>
      <Box ta="center">
        <StepHead>Parley lives in your menu bar</StepHead>
        <Text size="sm" c="dimmed" mt={4}>
          Look for ◉ at the top of your screen — it opens these settings. In any app, tap{' '}
          {KEY_LABELS[data.gestureKey]} {data.tapCount - 1}× and hold to talk.
        </Text>
      </Box>
      {missing.length > 0 && (
        <Box className={shell.glass} p="md">
          <Text size="sm" fw={600} mb="xs">
            Still to do
          </Text>
          <DataList withDivider labelWidth={130}>
            {missing.map(row => (
              <MissingRow
                key={row.label}
                label={row.label}
                value={row.value}
                onFix={() => goTo(row.step)}
              />
            ))}
          </DataList>
        </Box>
      )}
      <StepFoot>
        <Pressable>
          <Button variant="subtle" onClick={replayTour}>
            Take the tour
          </Button>
        </Pressable>
        <Pressable>
          <Button size="md" className={shell.primary} onClick={complete}>
            Start using Parley
          </Button>
        </Pressable>
      </StepFoot>
    </Stack>
  );
}
