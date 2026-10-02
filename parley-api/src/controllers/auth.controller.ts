import { Request, Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import * as authService from '../services/auth.service';

export const token = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.issueToken(req.body.email, req.body.label);
  res.status(201).json(result);
});
