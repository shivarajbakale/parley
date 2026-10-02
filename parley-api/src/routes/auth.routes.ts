import { Router } from 'express';
import { token } from '../controllers/auth.controller';
import { validate } from '../middleware/validate.middleware';
import { tokenRequestSchema } from '../types/auth.types';

const router = Router();
// Deliberately without requireAuth: this is how a client gets its first token.
router.post('/token', validate(tokenRequestSchema), token);
export default router;
