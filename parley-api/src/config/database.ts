import { PrismaClient } from '@prisma/client';
import { config } from './env';

// Reuse a single PrismaClient across hot-reloads in development to avoid
// exhausting database connections.
const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (!config.isProduction) {
  globalForPrisma.prisma = prisma;
}

export default prisma;
export { prisma };
