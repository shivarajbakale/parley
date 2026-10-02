import { createHash, randomBytes } from 'node:crypto';
import prisma from '../config/database';
import { AppError } from '../middleware/error.middleware';

export const hashToken = (token: string): string =>
  createHash('sha256').update(token).digest('hex');

export const parseBearer = (header: string | undefined): string | null => {
  if (!header) return null;
  const m = /^bearer\s+(\S+)$/i.exec(header);
  return m ? m[1] : null;
};

export const issueToken = async (email: string, label = '') => {
  const normalized = email.trim().toLowerCase();
  const user = await prisma.user.upsert({
    where: { email: normalized },
    update: {},
    create: { email: normalized },
  });
  const token = randomBytes(32).toString('base64url');
  await prisma.apiToken.create({ data: { userId: user.id, tokenHash: hashToken(token), label } });
  return { token, userId: user.id };
};

export const userIdForToken = async (token: string): Promise<string> => {
  const row = await prisma.apiToken.findUnique({ where: { tokenHash: hashToken(token) } });
  if (!row) throw new AppError('Invalid token', 401);
  return row.userId;
};
