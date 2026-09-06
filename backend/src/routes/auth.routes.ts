import { Router } from 'express';
import { AuthController } from '../controllers/auth.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { updateProfileSchema } from '../validators/auth.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All auth routes require valid Supabase access token
router.use(authenticateUser);

router.get('/profile', asyncWrapper(AuthController.getMe));
router.put(
  '/profile',
  validateRequest({ body: updateProfileSchema }),
  asyncWrapper(AuthController.updateMe)
);

export const authRoutes = router;
