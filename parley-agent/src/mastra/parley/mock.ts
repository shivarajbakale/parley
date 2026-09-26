import {
  MastraLanguageModelV2Mock,
  simulateReadableStream,
} from '@mastra/core/test-utils/llm-mock';

/**
 * Keyless stand-ins for the model, selected with `PARLEY_MODEL=mock:<name>`.
 * They exist so the Parley contract — run, stream, suspend, approve,
 * resume, completed — can be verified end to end with no API key and no
 * network, against the fixture MCP server or none at all. Never for real
 * commands: the mock answers the same way whatever was said.
 *
 * Tool names match the smoke fixture (`parley-smoke` server); with no
 * servers configured the calls fail closed and the run reports it.
 */

export type MockScenario = 'read' | 'write' | 'plain';

const TEXT_ID = 'mock-text-1';
const USAGE = { inputTokens: 0, outputTokens: 0, totalTokens: 0 };

function textStream(text: string) {
  return {
    stream: simulateReadableStream({
      chunks: [
        { type: 'text-start', id: TEXT_ID },
        { type: 'text-delta', id: TEXT_ID, delta: text },
        { type: 'text-end', id: TEXT_ID },
        { type: 'finish', finishReason: 'stop', usage: USAGE },
      ] as const,
    }),
  };
}

function toolStream(toolCallId: string, toolName: string, input: unknown) {
  return {
    stream: simulateReadableStream({
      chunks: [
        { type: 'tool-call', toolCallId, toolName, input: JSON.stringify(input) },
        { type: 'finish', finishReason: 'tool-calls', usage: USAGE },
      ] as const,
    }),
  };
}

export function createMockModel(scenario: MockScenario): MastraLanguageModelV2Mock {
  // A function, not the array form: the mock indexes canned responses by
  // call count after pushing, so the array's first entry is never served.
  // Extra calls repeat the last response, so a retried turn still settles.
  const script = (responses: (ReturnType<typeof textStream> | ReturnType<typeof toolStream>)[]) => {
    let calls = 0;
    return async () => responses[Math.min(calls++, responses.length - 1)] as never;
  };
  switch (scenario) {
    case 'read':
      // One free read, then the one-line answer.
      return new MastraLanguageModelV2Mock({
        provider: 'parley-mock',
        modelId: 'mock:read',
        doStream: script([
          toolStream('mock-call-1', 'parley-smoke_list_notes', {}),
          textStream('You have 2 notes: buy milk, call Ada.'),
        ]),
      });
    case 'write':
      // One write (suspends for approval), then the one-line answer.
      return new MastraLanguageModelV2Mock({
        provider: 'parley-mock',
        modelId: 'mock:write',
        doStream: script([
          toolStream('mock-call-1', 'parley-smoke_delete_note', { id: 'n1' }),
          textStream('Done — deleted note n1.'),
        ]),
      });
    case 'plain':
      return new MastraLanguageModelV2Mock({
        provider: 'parley-mock',
        modelId: 'mock:plain',
        doStream: script([textStream('Sorry — I cannot do that with the tools I have.')]),
      });
  }
}

export function isMockScenario(value: string): value is MockScenario {
  return value === 'read' || value === 'write' || value === 'plain';
}
