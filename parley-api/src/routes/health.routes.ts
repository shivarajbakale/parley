// Public on purpose, no requireAuth: load balancers probe it unauthenticated.
import { Router } from 'express';
import { healthCheck } from '../controllers/health.controller';

const router = Router();

router.get('/', healthCheck);

export default router;
