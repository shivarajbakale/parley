import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';

export const healthCheck = asyncHandler(async (req: Request, res: Response) => {
  res.status(200).json({
    status: 'success',
    message: 'Server is healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
