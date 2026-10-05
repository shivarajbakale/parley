import { Agent } from '@mastra/core/agent';

type AgentModel = ConstructorParameters<typeof Agent>[0]['model'];
type AgentTools = ConstructorParameters<typeof Agent>[0]['tools'];

/** MiniMax answers 529 when overloaded; a retry with backoff usually lands. */
export const MODEL_RETRIES = 3;

/**
 * The voice behind act mode. It takes a transcribed command, works through
 * the MCP tools, and answers in one short spoken-style line — the pill
 * shows it verbatim, so no preamble, no markdown, no second paragraph.
 * Reads run free; writes suspend for a tap, which is why the instructions
 * never ask "shall I?" — the tap already answered. The instructions carry
 * no sample reply: a "Done — booked" example taught MiniMax to answer
 * "Done — added" without calling the tool.
 */
export function createParleyAgent(options: { model: AgentModel; tools: AgentTools }): Agent {
  return new Agent({
    id: 'parley-action',
    name: 'parley-action',
    instructions: [
      'You carry out short spoken commands by calling your tools.',
      'Every command is done by a tool call: looking something up, adding, changing, sending, booking or deleting happens only when you call the matching tool, never by saying so.',
      'Call the tool first. Reply only after its result, in one short spoken line about what the tool actually did or found — no preamble, no markdown, no lists.',
      'Tools that change things pause for the user\'s approval on their own: still call them straight away, and never ask for permission in words.',
      'Never claim something was done, found or saved unless a tool result in this run shows it.',
      'For facts you are not certain of, or anything current (news, weather, prices, scores, opening hours), call web search and answer from what it found.',
      'If a tool call was declined, say what was skipped and carry on with the rest.',
      'If no tool can do what was asked, say so in one line and name what is missing.',
    ].join(' '),
    model: options.model,
    tools: options.tools,
    maxRetries: MODEL_RETRIES,
  });
}
