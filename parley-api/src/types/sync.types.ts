import { z } from 'zod';

export const SYNC_RESOURCES = ['dictionary', 'settings', 'history', 'tasks'] as const;
export type SyncResource = (typeof SYNC_RESOURCES)[number];

const ms = z.number().int().nonnegative();
const base = { id: z.string().min(1).max(64), updatedAt: ms, deletedAt: ms.nullable().optional() };

/** Credential-shaped names only: a bare `key`/`api_key`, anything `apikey`, tokens, secrets, passwords.
 * `gestureKey` and friends are hotkeys, not credentials, and must pass. */
const FORBIDDEN_SETTINGS_KEYS = /^(api_?key|key)$|apikey|token|secret|password/i;

export const dictionaryRow = z
  .object({
    ...base,
    word: z.string().max(60),
    soundsLike: z.array(z.string().min(1).max(60)).max(8),
  })
  .refine(r => r.deletedAt != null || r.word.length > 0, 'word required unless deleted');
export const settingsRow = z.object({
  ...base,
  data: z.record(z.unknown()).refine(
    d => Object.keys(d).every(k => !FORBIDDEN_SETTINGS_KEYS.test(k)),
    'settings must not carry keys, tokens or secrets',
  ),
});
export const historyRow = z.object({
  ...base,
  mode: z.enum(['dictate', 'edit', 'explain', 'act']),
  text: z.string().max(20_000),
  app: z.string().max(200).default(''),
  createdAt: ms,
});
export const taskRow = z.object({
  ...base,
  title: z.string().min(1).max(500),
  notes: z.string().max(20_000).default(''),
  dueAt: ms.nullable().optional(),
  rrule: z.string().max(500).nullable().optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  status: z.enum(['open', 'done', 'snoozed']).default('open'),
  sourceText: z.string().max(5_000).default(''),
});

const rowSchemas: Record<SyncResource, z.ZodTypeAny> = {
  dictionary: dictionaryRow,
  settings: settingsRow,
  history: historyRow,
  tasks: taskRow,
};
export const rowSchemaFor = (r: SyncResource): z.ZodTypeAny => rowSchemas[r];
export const pushSchemaFor = (r: SyncResource) => z.object({ items: z.array(rowSchemas[r]).max(500) });

export type DictionaryRow = z.infer<typeof dictionaryRow>;
export type SettingsRow = z.infer<typeof settingsRow>;
export type HistoryRow = z.infer<typeof historyRow>;
export type TaskRow = z.infer<typeof taskRow>;
export type AnyRow = DictionaryRow | SettingsRow | HistoryRow | TaskRow;
