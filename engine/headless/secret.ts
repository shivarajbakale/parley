import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

import type { CryptoLike } from '../settings-store';

/**
 * Encryption at rest for the one secret in settings, the sync token. The
 * key is 32 random bytes the native shell keeps in the Keychain and hands
 * over in `hello`; the engine never stores it. AES-256-GCM, with the IV and
 * tag packed before the ciphertext.
 *
 * Until the key arrives, encryption is unavailable and decryption fails,
 * which the settings store already reads as "no token".
 */
export interface KeyedCrypto extends CryptoLike {
  setKey(key: Buffer | null): void;
}

const IV_BYTES = 12;
const TAG_BYTES = 16;
const VERSION = 1;

export function createKeyedCrypto(): KeyedCrypto {
  let key: Buffer | null = null;

  return {
    setKey(next) {
      key = next && next.length === 32 ? Buffer.from(next) : null;
    },

    isEncryptionAvailable: () => key !== null,

    encryptString(plain) {
      if (!key) throw new Error('Encryption is not available');
      const iv = randomBytes(IV_BYTES);
      const cipher = createCipheriv('aes-256-gcm', key, iv);
      const body = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
      return Buffer.concat([Buffer.from([VERSION]), iv, cipher.getAuthTag(), body]);
    },

    decryptString(encrypted) {
      if (!key) throw new Error('Encryption is not available');
      if (encrypted.length < 1 + IV_BYTES + TAG_BYTES || encrypted[0] !== VERSION) {
        // An Electron safeStorage blob, or garbage: not ours to read.
        throw new Error('Not a Parley-encrypted value');
      }
      const iv = encrypted.subarray(1, 1 + IV_BYTES);
      const tag = encrypted.subarray(1 + IV_BYTES, 1 + IV_BYTES + TAG_BYTES);
      const body = encrypted.subarray(1 + IV_BYTES + TAG_BYTES);
      const decipher = createDecipheriv('aes-256-gcm', key, iv);
      decipher.setAuthTag(tag);
      return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
    },
  };
}
