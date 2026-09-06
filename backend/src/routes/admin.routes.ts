import { Router } from 'express';
import { AdminController } from '../controllers/admin.controller.js';
import { AdminAnalyticsController } from '../controllers/admin_analytics.controller.js';
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

// ─── Plan Limits (Centralized Configuration Management) ───
router.get('/plan-limits', asyncWrapper(AdminController.listPlanLimits));
router.put('/plan-limits/:id', asyncWrapper(AdminController.updatePlanLimit));
router.post('/plan-limits', asyncWrapper(AdminController.createPlanLimit));

// ─── User Analytics & Supabase Cost Control (MAU, DAU, Thresholds) ───
router.get('/analytics/users', asyncWrapper(AdminAnalyticsController.getUserAnalytics));
router.get('/analytics/alerts', asyncWrapper(AdminAnalyticsController.getCostAlerts));
router.post('/analytics/alerts/:id/acknowledge', asyncWrapper(AdminAnalyticsController.acknowledgeAlert));
router.get('/analytics/thresholds', asyncWrapper(AdminAnalyticsController.listThresholds));
router.put('/analytics/thresholds/:id', asyncWrapper(AdminAnalyticsController.updateThreshold));

export const adminRoutes = router;

