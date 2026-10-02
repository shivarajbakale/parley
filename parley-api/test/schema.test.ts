import { describe, it, expect } from 'vitest';
import { Prisma } from '@prisma/client';

const syncModels = ['DictionaryEntry', 'SettingsBlob', 'HistoryItem', 'Task'];

describe('sync schema', () => {
  for (const name of syncModels) {
    it(`${name} carries userId, updatedAt and deletedAt`, () => {
      const model = Prisma.dmmf.datamodel.models.find(m => m.name === name);
      expect(model, `${name} model`).toBeTruthy();
      const fields = Object.fromEntries(model!.fields.map(f => [f.name, f]));
      expect(fields.userId.type).toBe('String');
      expect(fields.updatedAt.type).toBe('BigInt');
      expect(fields.deletedAt.isRequired).toBe(false);
      expect(fields.syncedAt.type).toBe('BigInt');
      expect(model!.primaryKey?.fields).toEqual(['userId', 'id']);
    });
  }
  it('ApiToken stores a hash, never a token', () => {
    const model = Prisma.dmmf.datamodel.models.find(m => m.name === 'ApiToken')!;
    const names = model.fields.map(f => f.name);
    expect(names).toContain('tokenHash');
    expect(names).not.toContain('token');
  });
});
