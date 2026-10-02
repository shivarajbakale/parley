import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { logger } from '../utils/logger';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      correlationId?: string;
    }
  }
}

export const correlationId = (req: Request, res: Response, next: NextFunction): void => {
  // Check if correlation ID exists in headers, otherwise generate a new one
  const id = (req.headers['x-correlation-id'] as string) || randomUUID();

  // Attach correlation ID to request
  req.correlationId = id;

  // Set correlation ID in response headers
  res.setHeader('X-Correlation-Id', id);

  // Add correlation ID to winston logger's default meta
  logger.defaultMeta = { correlationId: id };

  next();
};
