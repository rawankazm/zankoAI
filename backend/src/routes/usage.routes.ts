import { Router } from 'express';
import { UsageController } from '../controllers/usage.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All usage routes require verified authentication
router.use(authenticateUser);

router.get('/status', asyncWrapper(UsageController.getStatus));
router.post('/check', asyncWrapper(UsageController.checkQuota));

export const usageRoutes = router;
export default usageRoutes;
