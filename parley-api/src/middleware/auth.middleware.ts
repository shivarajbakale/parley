import { Request, Response, NextFunction } from 'express';
import { AppError } from './error.middleware';
import { parseBearer, userIdForToken } from '../services/auth.service';

export const requireAuth = async (req: Request, _res: Response, next: NextFunction) => {
  const token = parseBearer(req.headers.authorization);
  if (!token) return next(new AppError('Missing bearer token', 401));
  try {
    req.userId = await userIdForToken(token);
    next();
  } catch (err) {
    next(err);
  }
};
