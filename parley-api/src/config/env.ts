import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env') });

/**
 * The one place the process environment is read.
 *
 * Every variable the app needs is named here, typed, with its default beside
 * it — so `.env.example` has a single source to match and a missing variable
 * is a compile-time surface rather than an `undefined` discovered in
 * production. `make api-lint` (rule A2) fails the build on a second reader.
 */
interface Config {
  nodeEnv: string;
  isProduction: boolean;
  port: number;
  apiPrefix: string;
  databaseUrl: string;
  frontendUrl?: string;
}

const nodeEnv = process.env.NODE_ENV || 'development';

export const config: Config = {
  nodeEnv,
  isProduction: nodeEnv === 'production',
  port: parseInt(process.env.PORT || '3100', 10),
  apiPrefix: process.env.API_PREFIX || '/api',
  databaseUrl: process.env.DATABASE_URL || 'file:./dev.db',
  frontendUrl: process.env.FRONTEND_URL,
};
