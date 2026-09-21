import { useEffect, useRef, useState } from 'react';
import { ActionIcon, Skeleton, Stack, Tooltip } from '@mantine/core';
import { Check, Copy, Sparkles, X } from 'lucide-react';
import Markdown from 'react-markdown';

import type { ExplainState } from '../../electron/types';

import classes from './ExplainCard.module.css';

/**
 * The card only reads what main pushes and reports how tall it rendered, so
 * main can size the window to fit. Nothing here can navigate: links render as
 * plain text, and the markdown renderer never emits raw HTML.
 */

function Body({ state }: { state: ExplainState }) {
  switch (state.status) {
    case 'loading':
      return (
        <Stack gap={8} aria-label="Explaining" role="status" pt={4}>
          <Skeleton height={12} radius="sm" />
          <Skeleton height={12} radius="sm" width="88%" />
          <Skeleton height={12} radius="sm" width="64%" />
        </Stack>
      );
    case 'empty':
      return <p className={classes.message}>Select some text first</p>;
    case 'error':
      return (
        <p className={classes.error} role="alert">
          {state.message}
        </p>
      );
    case 'ready':
      return (
        <div className={classes.markdown} key="answer">
          <Markdown components={{ a: ({ children }) => <span>{children}</span> }}>
            {state.markdown}
          </Markdown>
        </div>
      );
  }
}

/** The header names what was asked, or just the command when nothing was. */
function Title({ state }: { state: ExplainState }) {
  const question = 'question' in state ? state.question : undefined;
  return (
    <span className={classes.title} title={question}>
      <Sparkles size={14} className={classes.spark} aria-hidden />
      {question ? <span className={classes.question}>{question}</span> : 'Explain'}
    </span>
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

  useEffect(() => {
    const element = card.current;
    if (!element || typeof ResizeObserver === 'undefined') return;
    const report = () => window.parley.reportExplainHeight(Math.ceil(element.offsetHeight));
    const observer = new ResizeObserver(report);
    observer.observe(element);
    report();
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={card}
      className={`${classes.card} ${state.closing ? classes.leaving : ''}`}
      role="region"
      aria-label="Explanation"
      style={{ maxHeight: state.maxHeight }}
    >
      <div className={classes.header}>
        <Title state={state} />
        <div className={classes.actions}>
          {state.status === 'ready' && <CopyButton markdown={state.markdown} />}
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
        <Body state={state} />
      </div>
    </div>
  );
}

/**
 * Empty until main pushes the first state, so a hidden card paints nothing.
 * A new question remounts the card, which replays its entrance; the answer
 * arriving for the same question updates it in place.
 */
export function ExplainApp() {
  const [state, setState] = useState<ExplainState | null>(null);
  const [epoch, setEpoch] = useState(0);
  useEffect(
    () =>
      window.parley.onExplain((next) => {
        if (next.status === 'loading' || next.status === 'empty') setEpoch((n) => n + 1);
        setState(next);
      }),
    []
  );
  return state ? <ExplainCard key={epoch} state={state} /> : null;
}
