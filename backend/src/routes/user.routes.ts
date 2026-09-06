import { Router } from 'express';
import { UserController } from '../controllers/user.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { updateUserProfileSchema } from '../validators/user.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All user management routes require an authenticated user
router.use(authenticateUser);

router.get('/', asyncWrapper(UserController.listUsers));
router.get('/:id', asyncWrapper(UserController.getUser));
router.patch(
  '/:id',
  validateRequest({ body: updateUserProfileSchema }),
  asyncWrapper(UserController.updateUser)
);
router.delete(
  '/:id',
  requireRole(['admin']),
  asyncWrapper(UserController.deleteUser)
);

export const userRoutes = router;
