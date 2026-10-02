import { describe, it, expect } from 'vitest';
import { hashToken, parseBearer } from '../src/services/auth.service';

describe('auth helpers', () => {
  it('hashes deterministically and never returns the input', () => {
    const h = hashToken('abc');
    expect(h).toBe(hashToken('abc'));
    expect(h).not.toContain('abc');
    expect(h).toHaveLength(64);
  });
  it('parses a bearer header and rejects others', () => {
    expect(parseBearer('Bearer xyz')).toBe('xyz');
    expect(parseBearer('bearer xyz')).toBe('xyz');
    expect(parseBearer('Basic xyz')).toBeNull();
    expect(parseBearer(undefined)).toBeNull();
  });
});
