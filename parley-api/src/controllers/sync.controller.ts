import { Request, Response } from 'express';
import { asyncHandler, AppError } from '../middleware/error.middleware';
import * as syncService from '../services/sync.service';
import type { SyncResource } from '../types/sync.types';

export const pullFor = (resource: SyncResource) =>
  asyncHandler(async (req: Request, res: Response) => {
    const raw = req.query.since;
    const since = raw === undefined ? 0 : Number(raw);
    if (!Number.isInteger(since) || since < 0) throw new AppError('since must be a non-negative integer', 400);
    const { rows, hasMore, cursor } = await syncService.pull(resource, req.userId!, since);
    res.locals.meta = { now: cursor, hasMore };
    res.status(200).json(rows);
  });

export const pushFor = (resource: SyncResource) =>
  asyncHandler(async (req: Request, res: Response) => {
    const now = Date.now();
    const data = await syncService.push(resource, req.userId!, req.body.items, now);
    res.locals.meta = { now };
    res.status(200).json(data);
  });
