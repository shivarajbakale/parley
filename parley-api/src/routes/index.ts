import { Router } from 'express';
import authRoutes from './auth.routes';
import healthRoutes from './health.routes';
import meRoutes from './me.routes';
import { syncRouter } from './sync.routes';
import { SYNC_RESOURCES } from '../types/sync.types';

const router = Router();

// Auth is applied per route file: me routes call requireAuth; health and auth are public.
router.use('/auth', authRoutes);
router.use('/health', healthRoutes);
router.use('/me', meRoutes);
for (const resource of SYNC_RESOURCES) router.use(`/${resource}`, syncRouter(resource));

export default router;
