import type { TranscriptionProvider } from '../../electron/types';

/** How each transcription provider is named in the settings window. */
export interface ProviderCopy {
  /** The SegmentedControl label. */
  label: string;
  /** The key field's label; the tests find the field by it. */
  keyLabel: string;
  placeholder: string;
  /** What turns speech into text, as a sentence subject. */
  service: string;
  /** Who the vocabulary is for: "Names and jargon ___ should recognise". */
  listener: string;
}

export const PROVIDER_COPY: Record<TranscriptionProvider, ProviderCopy> = {
  groq: {
    label: 'Whisper (Groq)',
    keyLabel: 'Groq API key',
    placeholder: 'gsk_…',
    service: 'Groq’s Whisper',
    listener: 'Whisper',
  },
  deepgram: {
    label: 'Deepgram Nova-3',
    keyLabel: 'Deepgram API key',
    placeholder: 'Paste your key',
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
