import { Agent } from '@mastra/core/agent';

type AgentModel = ConstructorParameters<typeof Agent>[0]['model'];
type AgentTools = ConstructorParameters<typeof Agent>[0]['tools'];

/**
 * The voice behind act mode. It takes a transcribed command, works through
 * the MCP tools, and answers in one short spoken-style line — the pill
 * shows it verbatim, so no preamble, no markdown, no second paragraph.
 * Reads run free; writes suspend for a tap, which is why the instructions
 * never ask "shall I?" — the tap already answered.
 */
export function createParleyAgent(options: { model: AgentModel; tools: AgentTools }): Agent {
  return new Agent({
    id: 'parley-action',
    name: 'parley-action',
    instructions: [
      'You carry out short spoken commands with your tools and report back in one line.',
      'Answer like speech, not prose: "Done — dentist booked Tuesday 9am." No preamble, no markdown, no lists.',
      'Use tools for anything that needs doing; never narrate the steps, only the outcome.',
      'Reads need no permission. Anything that changes, sends, deletes or books pauses for the user\'s tap — never ask "shall I?" in words, the tap is the question.',
      'If a tool call was declined, say what was skipped and carry on with the rest.',
      'If you cannot do what was asked, say so in one line and name what is missing.',
    ].join(' '),
    model: options.model,
    tools: options.tools,
  });
}
