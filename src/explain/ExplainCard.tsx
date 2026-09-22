import { useEffect, useRef, useState } from 'react';
import { ActionIcon, Skeleton, Stack, Tooltip } from '@mantine/core';
import { Check, Copy, Sparkles, X } from 'lucide-react';
import Markdown from 'react-markdown';

import type { ExplainState, ExplainTurn } from '../../electron/types';

import classes from './ExplainCard.module.css';

/**
 * The card only reads what main pushes and reports how tall it rendered, so
 * main can size the window to fit. Nothing here can navigate: links render as
 * plain text, and the markdown renderer never emits raw HTML.
 *
 * A thread is every question asked of one selection, oldest first. A
 * follow-up (the gesture again while the card is open) appends a turn; the
 * card grows and scrolls to it instead of resetting.
 */

function TurnBody({ turn }: { turn: ExplainTurn }) {
  switch (turn.status) {
    case 'loading':
      return (
        <Stack gap={8} aria-label="Explaining" role="status" pt={2}>
          <Skeleton height={12} radius="sm" />
          <Skeleton height={12} radius="sm" width="88%" />
          <Skeleton height={12} radius="sm" width="64%" />
        </Stack>
      );
    case 'error':
      return (
        <p className={classes.error} role="alert">
          {turn.message}
        </p>
      );
    case 'ready':
      return (
        <div className={classes.markdown}>
          <Markdown components={{ a: ({ children }) => <span>{children}</span> }}>
            {turn.markdown}
          </Markdown>
        </div>
      );
  }
}

function Turn({ turn, isFollowUp, focusRef }: {
  turn: ExplainTurn;
  isFollowUp: boolean;
  focusRef?: React.Ref<HTMLDivElement>;
}) {
  return (
    <div ref={focusRef} className={isFollowUp ? classes.followUp : undefined}>
      {turn.question && (
        <p className={classes.question}>
          {isFollowUp && <span className={classes.questionArrow}>↳</span>}
          {turn.question}
        </p>
      )}
      <TurnBody turn={turn} />
    </div>
  );
}

function CopyButton({ markdown }: { markdown: string }) {
  const [copied, setCopied] = useState(false);
  const label = copied ? 'Copied' : 'Copy';
  return (
    <Tooltip label={label} position="left" withArrow={false} openDelay={200}>
      <ActionIcon
        variant="subtle"
        size="sm"
        color={copied ? 'teal' : 'gray'}
        aria-label="Copy"
        onClick={() => {
          window.parley.copyExplain(markdown);
          setCopied(true);
          setTimeout(() => setCopied(false), 1400);
        }}
      >
        {copied ? <Check size={14} /> : <Copy size={14} />}
      </ActionIcon>
    </Tooltip>
  );
}

export function ExplainCard({ state }: { state: ExplainState }) {
  const card = useRef<HTMLDivElement>(null);
  const latestTurn = useRef<HTMLDivElement>(null);
  const turnCount = state.status === 'thread' ? state.turns.length : 0;

  useEffect(() => {
    const element = card.current;
    if (!element || typeof ResizeObserver === 'undefined') return;
    const report = () => window.parley.reportExplainHeight(Math.ceil(element.offsetHeight));
    const observer = new ResizeObserver(report);
    observer.observe(element);
    report();
    return () => observer.disconnect();
  }, []);

  // A follow-up's answer is the one thing to look at: keep it on screen even
  // once the card has grown taller than the window allows.
  useEffect(() => {
    if (turnCount > 1) latestTurn.current?.scrollIntoView({ block: 'nearest' });
  }, [turnCount]);

  const lastReady =
    state.status === 'thread'
      ? [...state.turns].reverse().find((t): t is Extract<ExplainTurn, { status: 'ready' }> => t.status === 'ready')
      : undefined;

  return (
    <div
      ref={card}
      className={`${classes.card} ${state.closing ? classes.leaving : ''}`}
      role="region"
      aria-label="Explanation"
      style={{ maxHeight: state.maxHeight }}
    >
      <div className={classes.header}>
        <span className={classes.title}>
          <Sparkles size={14} className={classes.spark} aria-hidden />
          Explain
        </span>
        <div className={classes.actions}>
          {lastReady && <CopyButton markdown={lastReady.markdown} />}
          <ActionIcon
            variant="subtle"
            size="sm"
            color="gray"
            aria-label="Close"
            onClick={() => window.parley.dismissExplain()}
          >
            <X size={14} />
          </ActionIcon>
        </div>
      </div>
      <div className={classes.body}>
        {state.status === 'empty' && <p className={classes.message}>Select some text first</p>}
        {state.status === 'thread' &&
          state.turns.map((turn, i) => (
            <Turn
              key={i}
              turn={turn}
              isFollowUp={i > 0}
              focusRef={i === state.turns.length - 1 ? latestTurn : undefined}
            />
          ))}
      </div>
    </div>
  );
}

/**
 * Empty until main pushes the first state, so a hidden card paints nothing.
 * `opening` (set only when main's `view.show()` ran) replays the entrance;
 * a follow-up turn just updates in place and scrolls to itself.
 */
export function ExplainApp() {
  const [state, setState] = useState<ExplainState | null>(null);
  const [epoch, setEpoch] = useState(0);
  useEffect(
    () =>
      window.parley.onExplain((next) => {
        if (next.opening) setEpoch((n) => n + 1);
        setState(next);
      }),
    []
  );
  return state ? <ExplainCard key={epoch} state={state} /> : null;
}
