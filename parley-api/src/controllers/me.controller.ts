import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';

export const me = asyncHandler(async (req: Request, res: Response) => {
  res.json({ userId: req.userId });
});
