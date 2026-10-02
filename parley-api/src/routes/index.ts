import { Router } from 'express';
import authRoutes from './auth.routes';
import healthRoutes from './health.routes';
import userRoutes from './user.routes';

const router = Router();

// Auth is applied per route file: user routes call requireAuth; health and auth are public.
router.use('/auth', authRoutes);
router.use('/health', healthRoutes);
router.use('/users', userRoutes);

export default router;
