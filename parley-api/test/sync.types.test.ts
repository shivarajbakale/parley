import { describe, it, expect } from 'vitest';
import { SYNC_RESOURCES, rowSchemaFor, pushSchemaFor } from '../src/types/sync.types';

describe('sync schemas', () => {
  it('names the four resources', () => {
    expect(SYNC_RESOURCES).toEqual(['dictionary', 'settings', 'history', 'tasks']);
  });
  it('rejects API keys inside the settings blob', () => {
    const r = rowSchemaFor('settings').safeParse({
      id: 'x', updatedAt: 1, data: { apiKey: 'gsk_123' },
    });
    expect(r.success).toBe(false);
  });
  it('rejects credential-shaped names but accepts gesture keys', () => {
    const s = rowSchemaFor('settings');
    for (const name of ['groqApiKey', 'token', 'secret', 'password', 'key', 'api_key']) {
      expect(s.safeParse({ id: 'x', updatedAt: 1, data: { [name]: 'v' } }).success, name).toBe(false);
    }
    expect(
      s.safeParse({ id: 'x', updatedAt: 1, data: { gestureKey: 'AltRight', editGestureKey: 'MetaRight' } }).success,
    ).toBe(true);
  });
  it('caps a push at 500 items', () => {
    const items = Array.from({ length: 501 }, (_, i) => ({ id: `d${i}`, word: 'w', soundsLike: [], updatedAt: 1 }));
    expect(pushSchemaFor('dictionary').safeParse({ items }).success).toBe(false);
  });
  it('allows an empty word only on a tombstone', () => {
    const s = rowSchemaFor('dictionary');
    expect(s.safeParse({ id: 'x', word: '', soundsLike: [], updatedAt: 1, deletedAt: 1 }).success).toBe(true);
    expect(s.safeParse({ id: 'x', word: '', soundsLike: [], updatedAt: 1 }).success).toBe(false);
  });
});
