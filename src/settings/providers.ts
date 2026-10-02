import type { TranscriptionProvider } from '../../electron/types';

/** How each transcription provider is named in the settings window. */
export interface ProviderCopy {
  /** The SegmentedControl label. */
  label: string;
  /** The variable that holds its key in parley-api/.env. */
  envVar: string;
  /** What turns speech into text, as a sentence subject. */
  service: string;
  /** Who the vocabulary is for: "Names and jargon ___ should recognise". */
  listener: string;
}

export const PROVIDER_COPY: Record<TranscriptionProvider, ProviderCopy> = {
  groq: {
    label: 'Whisper (Groq)',
    envVar: 'GROQ_API_KEY',
    service: 'Groq’s Whisper',
    listener: 'Whisper',
  },
  deepgram: {
    label: 'Deepgram Nova-3',
    envVar: 'DEEPGRAM_API_KEY',
    service: 'Deepgram Nova-3',
    listener: 'Deepgram',
  },
};

export const PROVIDER_OPTIONS = (Object.keys(PROVIDER_COPY) as TranscriptionProvider[]).map(
  value => ({ value, label: PROVIDER_COPY[value].label })
);

/** Settings written before the provider existed have none: they are Groq. */
export function providerOf(settings: { transcriptionProvider?: TranscriptionProvider }) {
  return settings.transcriptionProvider ?? 'groq';
}
