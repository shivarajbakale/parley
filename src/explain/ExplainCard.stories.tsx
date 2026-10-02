import type { Meta, StoryObj } from '@storybook/react';

import type { ParleyApi } from '../../electron/types';

import { ExplainCard } from './ExplainCard';

/** The card only calls back into main; in Storybook those calls go nowhere. */
function withParley(Story: () => React.JSX.Element) {
  window.parley = {
    reportExplainHeight: () => {},
    copyExplain: () => {},
    dismissExplain: () => {},
    openExternal: () => {},
  } as unknown as ParleyApi;
  return <Story />;
}

const ANSWER = `In plain words: calling a PUT handler several times with the same data leaves the system exactly as calling it once.

**Why it matters:** a request can be retried safely. If the network drops and the same PUT goes out twice, nothing is created twice.

- **Idempotent** means repeating an operation does not change the result after the first time.
- Compare **POST**, which creates a record each time it is sent.`;

/**
 * The Explain popover as parley-api streams an answer into it: shimmer before
 * the first words, a search line, text growing with a live caret, then the
 * pages it searched as sources.
 */
const meta = {
  title: 'Parley/Explain/ExplainCard',
  component: ExplainCard,
  tags: ['autodocs'],
  parameters: { layout: 'centered' },
  decorators: [withParley],
  argTypes: {
    state: {
      control: 'object',
      description:
        'What main pushes: `empty`, or a `thread` of turns (loading, streaming, ready, error) plus the height cap.',
    },
  },
} satisfies Meta<typeof ExplainCard>;

export default meta;
type Story = StoryObj<typeof ExplainCard>;

export const Loading: Story = {
  args: { state: { status: 'thread', turns: [{ status: 'loading' }], maxHeight: 520 } },
};

export const Searching: Story = {
  args: {
    state: {
      status: 'thread',
      turns: [{ question: 'what changed in this release?', status: 'loading', searching: 'Mastra 1.67 release notes' }],
      maxHeight: 520,
    },
  },
};

export const Streaming: Story = {
  args: {
    state: {
      status: 'thread',
      turns: [{ status: 'streaming', markdown: ANSWER.slice(0, 190) }],
      maxHeight: 520,
    },
  },
};

export const ReadyWithSources: Story = {
  args: {
    state: {
      status: 'thread',
      turns: [
        {
          status: 'ready',
          markdown: ANSWER,
          sources: [
            { title: 'RFC 9110: HTTP Semantics', url: 'https://www.rfc-editor.org/rfc/rfc9110' },
            { title: 'Idempotent - MDN Web Docs Glossary', url: 'https://developer.mozilla.org/en-US/docs/Glossary/Idempotent' },
          ],
        },
      ],
      maxHeight: 520,
    },
  },
};

export const ErrorAfterText: Story = {
  args: {
    state: {
      status: 'thread',
      turns: [{ status: 'error', markdown: ANSWER.slice(0, 120), message: 'The answer stopped early' }],
      maxHeight: 520,
    },
  },
};

export const ServerUnreachable: Story = {
  args: {
    state: {
      status: 'thread',
      turns: [{ status: 'error', message: "Can't reach the Parley server at http://localhost:3100" }],
      maxHeight: 520,
    },
  },
};
