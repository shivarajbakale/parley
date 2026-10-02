import { Router } from 'express';
import {
  getAllUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser
} from '../controllers/user.controller';
import { validate } from '../middleware/validate.middleware';
import { createUserSchema, updateUserSchema } from '../types/user.types';

const router = Router();

router.get('/', getAllUsers);

router.get('/:id', getUserById);

router.post('/', validate(createUserSchema), createUser);

router.put('/:id', validate(updateUserSchema), updateUser);

router.delete('/:id', deleteUser);

export default router;
