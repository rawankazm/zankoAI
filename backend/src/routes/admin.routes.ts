import { Router } from 'express';
import { AdminController } from '../controllers/admin.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { updateUserRoleSchema, updateAccountStatusSchema } from '../validators/admin.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// Protected: Requires authentication + admin role
router.use(authenticateUser);
router.use(requireRole(['admin']));

router.get('/users', asyncWrapper(AdminController.listUsers));
router.post(
  '/users/role',
  validateRequest({ body: updateUserRoleSchema }),
  asyncWrapper(AdminController.setUserRole)
);
router.post(
  '/users/status',
  validateRequest({ body: updateAccountStatusSchema }),
  asyncWrapper(AdminController.setUserStatus)
);
router.get('/stats', asyncWrapper(AdminController.getSystemStats));

export const adminRoutes = router;
