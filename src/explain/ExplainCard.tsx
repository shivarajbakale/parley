import { useEffect, useRef, useState } from 'react';
import { Button, Skeleton, Stack } from '@mantine/core';
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
        <div className={classes.markdown}>
          <Markdown components={{ a: ({ children }) => <span>{children}</span> }}>
            {state.markdown}
          </Markdown>
        </div>
      );
  }
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
    <div ref={card} className={classes.card} style={{ maxHeight: state.maxHeight }}>
      <div className={classes.header}>
        <span className={classes.label}>Explain</span>
        {state.status === 'ready' && (
          <Button
            variant="subtle"
            size="compact-xs"
            onClick={() => window.parley.copyExplain(state.markdown)}
          >
            Copy
          </Button>
        )}
      </div>
      <div className={classes.body}>
        <Body state={state} />
      </div>
    </div>
  );
}

/** Empty until main pushes the first state, so a hidden card paints nothing. */
export function ExplainApp() {
  const [state, setState] = useState<ExplainState | null>(null);
  useEffect(() => window.parley.onExplain(setState), []);
  return state ? <ExplainCard state={state} /> : null;
}
