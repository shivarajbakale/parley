import { Router } from 'express';
import { me } from '../controllers/me.controller';
import { requireAuth } from '../middleware/auth.middleware';

const router = Router();

router.use(requireAuth);
router.get('/', me);

export default router;
