import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ActionIcon, Anchor, Group, Loader, Skeleton, Stack, Text, Tooltip } from '@mantine/core';
import { Check, Copy, Sparkles, X } from 'lucide-react';
import Markdown from 'react-markdown';

import type { ExplainSource, ExplainState, ExplainTurn } from '../../electron/types';

import classes from './ExplainCard.module.css';
import { tidyPartial } from './tidy-partial';

/**
 * The card only reads what main pushes and reports how tall it rendered, so
 * main can size the window to fit. Nothing here can navigate: links render as
 * plain text, and the markdown renderer never emits raw HTML.
 *
 * A thread is every question asked of one selection, oldest first. A
 * follow-up (the gesture again while the card is open) appends a turn; the
 * card grows and scrolls to it instead of resetting.
 *
 * An answer streams in: the same markdown block grows in place (so it never
 * remounts or replays its entrance), a search line says what the agent is
 * looking up, and once done the pages it really searched are listed as
 * sources that open in the browser through main.
 */

/** Within this many pixels of the bottom, the body follows new text down. */
const FOLLOW_SLACK_PX = 24;

function siteName(source: ExplainSource): string {
  try {
    return new URL(source.url).hostname.replace(/^www\./, '');
  } catch {
    return source.title;
  }
}

function SearchLine({ query }: { query: string }) {
  return (
    <Group gap={8} wrap="nowrap" role="status" aria-label="Searching" className={classes.searching}>
      <Loader size={12} color="violet" />
      <Text size="xs" c="dimmed" truncate style={{ minWidth: 0 }}>
        Searching “{query}”
      </Text>
    </Group>
  );
}

function Sources({ sources }: { sources: ExplainSource[] }) {
  return (
    <Group gap={6} className={classes.sources}>
      <Text size="xs" c="dimmed">
        Sources
      </Text>
      {sources.map((source, i) => (
        <Group key={source.url} gap={6} wrap="nowrap">
          {i > 0 && (
            <Text size="xs" c="dimmed" aria-hidden>
              ·
            </Text>
          )}
          <Anchor
            component="button"
            type="button"
            size="xs"
            c="violet.3"
            title={source.title}
            className={classes.source}
            onClick={() => window.parley.openExternal(source.url)}
          >
            {siteName(source)}
          </Anchor>
        </Group>
      ))}
    </Group>
  );
}

/**
 * One layout for every status, so the answer block keeps its place in the
 * tree as a turn goes loading, streaming, ready (or error) and is never
 * remounted mid-read.
 */
function TurnBody({ turn }: { turn: ExplainTurn }) {
  const markdown = turn.status === 'loading' ? undefined : turn.markdown;
  const searching = turn.status === 'loading' || turn.status === 'streaming' ? turn.searching : undefined;
  return (
    <>
      {turn.status === 'loading' && !searching && (
        <Stack gap={8} aria-label="Explaining" role="status" pt={2}>
          <Skeleton height={12} radius="sm" />
          <Skeleton height={12} radius="sm" width="88%" />
          <Skeleton height={12} radius="sm" width="64%" />
        </Stack>
      )}
      {markdown ? (
        <div className={`${classes.markdown} ${turn.status === 'streaming' && !searching ? classes.live : ''}`}>
          <Markdown components={{ a: ({ children }) => <span>{children}</span> }}>
            {turn.status === 'ready' ? markdown : tidyPartial(markdown)}
          </Markdown>
        </div>
      ) : null}
      {searching && <SearchLine query={searching} />}
      {turn.status === 'ready' && turn.sources?.length ? <Sources sources={turn.sources} /> : null}
      {turn.status === 'error' && (
        <p className={classes.error} role="alert">
          {turn.message}
        </p>
      )}
    </>
  );
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
  const body = useRef<HTMLDivElement>(null);
  const latestTurn = useRef<HTMLDivElement>(null);
  /** Whether the body is scrolled to its end, so new text should follow. */
  const following = useRef(true);
  const turnCount = state.status === 'thread' ? state.turns.length : 0;
  const busy =
    state.status === 'thread' && state.turns.some((t) => t.status === 'loading' || t.status === 'streaming');

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

  // Past the height cap the newest words land below the fold: keep them in
  // view, unless the reader has scrolled up to reread.
  useLayoutEffect(() => {
    const element = body.current;
    if (element && busy && following.current) element.scrollTop = element.scrollHeight;
  });

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
      aria-busy={busy}
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
      <div
        ref={body}
        className={classes.body}
        onScroll={(event) => {
          const element = event.currentTarget;
          following.current = element.scrollHeight - element.scrollTop - element.clientHeight < FOLLOW_SLACK_PX;
        }}
      >
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
