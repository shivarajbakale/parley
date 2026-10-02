import { Router } from 'express';
import { requireAuth } from '../middleware/auth.middleware';
import { validate } from '../middleware/validate.middleware';
import { pullFor, pushFor } from '../controllers/sync.controller';
import { pushSchemaFor, type SyncResource } from '../types/sync.types';

/** One router shape for every resource: GET ?since, PUT { items }. */
export const syncRouter = (resource: SyncResource) => {
  const router = Router();
  router.use(requireAuth);
  router.get('/', pullFor(resource));
  router.put('/', validate(pushSchemaFor(resource)), pushFor(resource));
  return router;
};
