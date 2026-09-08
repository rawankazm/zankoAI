import { Router } from 'express';
import { AdminController } from '../controllers/admin.controller.js';
import { AdminAnalyticsController } from '../controllers/admin_analytics.controller.js';
import { AdminAiController } from '../controllers/admin_ai.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  listUsersQuerySchema,
  userIdParamSchema,
  patchUserStatusBodySchema,
  patchUserPlanBodySchema,
  patchUserRoleBodySchema,
  updateUserRoleSchema,
  updateAccountStatusSchema,
  listSubscriptionsQuerySchema,
  listPaymentsQuerySchema,
  listAuditLogsQuerySchema,
  getUsageQuerySchema,
} from '../validators/admin.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// ==============================================================================
// STRICT AUTHORIZATION: All routes in /api/admin/* require valid authentication
// and role === 'admin'. No exceptions.
// ==============================================================================
router.use(authenticateUser);
router.use(requireRole(['admin']));

// ─── 1. Users Management ────────────────────────────────────────────────────
router.get(
  '/users',
  validateRequest({ query: listUsersQuerySchema }),
  asyncWrapper(AdminController.listUsers)
);

router.patch(
  '/users/:id/status',
  validateRequest({ params: userIdParamSchema, body: patchUserStatusBodySchema }),
  asyncWrapper(AdminController.updateUserStatus)
);

router.patch(
  '/users/:id/plan',
  validateRequest({ params: userIdParamSchema, body: patchUserPlanBodySchema }),
  asyncWrapper(AdminController.updateUserPlan)
);

router.patch(
  '/users/:id/role',
  validateRequest({ params: userIdParamSchema, body: patchUserRoleBodySchema }),
  asyncWrapper(AdminController.setUserRole)
);

// Legacy compatible endpoints for frontend admin sheet
router.post(
  '/users/role',
  validateRequest({ body: updateUserRoleSchema }),
  asyncWrapper(AdminController.setUserRole)
);
router.post(
  '/users/status',
  validateRequest({ body: updateAccountStatusSchema }),
  asyncWrapper(AdminController.updateUserStatus)
);
router.post('/users/vip', asyncWrapper(AdminController.setUserVip));

// ─── 2. Subscriptions & Payments ────────────────────────────────────────────
router.get(
  '/subscriptions',
  validateRequest({ query: listSubscriptionsQuerySchema }),
  asyncWrapper(AdminController.listSubscriptions)
);

router.get(
  '/payments',
  validateRequest({ query: listPaymentsQuerySchema }),
  asyncWrapper(AdminController.listPayments)
);

// ─── 3. Usage & System Telemetry ───────────────────────────────────────────
router.get(
  '/usage',
  validateRequest({ query: getUsageQuerySchema }),
  asyncWrapper(AdminController.getSystemUsage)
);

router.get('/stats', asyncWrapper(AdminController.getSystemStats));
router.get('/reports', asyncWrapper(AdminController.getReports));

// ─── 4. Immutable Audit Logs ───────────────────────────────────────────────
router.get(
  '/audit-logs',
  validateRequest({ query: listAuditLogsQuerySchema }),
  asyncWrapper(AdminController.listAuditLogs)
);

// ─── 5. Academic Directory ──────────────────────────────────────────────────
router.get('/universities', asyncWrapper(AdminController.listUniversities));
router.get('/faculties', asyncWrapper(AdminController.listFaculties));
router.get('/departments', asyncWrapper(AdminController.listDepartments));
router.get('/courses', asyncWrapper(AdminController.listCourses));

// ─── 6. Plan Limits ─────────────────────────────────────────────────────────
router.get('/plan-limits', asyncWrapper(AdminController.listPlanLimits));
router.put('/plan-limits/:id', asyncWrapper(AdminController.updatePlanLimit));
router.post('/plan-limits', asyncWrapper(AdminController.createPlanLimit));

// ─── 7. User Analytics & Alerts (MAU, DAU, Thresholds) ──────────────────────
router.get('/analytics/users', asyncWrapper(AdminAnalyticsController.getUserAnalytics));
router.get('/analytics/alerts', asyncWrapper(AdminAnalyticsController.getCostAlerts));
router.post('/analytics/alerts/:id/acknowledge', asyncWrapper(AdminAnalyticsController.acknowledgeAlert));
router.get('/analytics/thresholds', asyncWrapper(AdminAnalyticsController.listThresholds));
router.put('/analytics/thresholds/:id', asyncWrapper(AdminAnalyticsController.updateThreshold));

// ─── 8. AI Cost Control & Monitoring ─────────────────────────────────────────
router.get('/ai/usage', asyncWrapper(AdminAiController.getAiUsage));
router.get('/ai/cost', asyncWrapper(AdminAiController.getAiCost));
router.get('/ai/limits', asyncWrapper(AdminAiController.getAiLimits));
router.put('/ai/limits/:plan', asyncWrapper(AdminAiController.updateAiLimits));
router.get('/ai/alerts', asyncWrapper(AdminAiController.getAiAlerts));
router.post('/ai/alerts/:id/acknowledge', asyncWrapper(AdminAiController.acknowledgeAlert));

export const adminRoutes = router;
