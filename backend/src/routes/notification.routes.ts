// ==============================================================================
// ZankoAI Production Notification Routes
// Mounted at: /api/notifications
// ==============================================================================

import { Router } from 'express';
import { NotificationController } from '../controllers/notification.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  updateNotificationPreferencesSchema,
  scheduleNotificationSchema,
} from '../validators/calendar_notification.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All notification endpoints require authenticated user
router.use(authenticateUser);

// ─── Notification Operations ───
// GET /api/notifications (paginated & filtered)
router.get('/', asyncWrapper(NotificationController.listNotifications));

// PATCH /api/notifications/:id/read (mark single notification as read)
router.patch('/:id/read', asyncWrapper(NotificationController.markAsRead));

// POST /api/notifications/read-all (mark all as read)
router.post('/read-all', asyncWrapper(NotificationController.markAllAsRead));

// DELETE /api/notifications/:id (delete notification)
router.delete('/:id', asyncWrapper(NotificationController.deleteNotification));

// ─── Notification Preferences ───
// GET /api/notifications/preferences
router.get('/preferences', asyncWrapper(NotificationController.getPreferences));

// PATCH /api/notifications/preferences
router.patch(
  '/preferences',
  validateRequest({ body: updateNotificationPreferencesSchema }),
  asyncWrapper(NotificationController.updatePreferences)
);

// ─── Scheduled Notification Dispatch ───
// POST /api/notifications/schedule
router.post(
  '/schedule',
  validateRequest({ body: scheduleNotificationSchema }),
  asyncWrapper(NotificationController.scheduleNotification)
);

export const notificationRoutes = router;
