import { Router } from 'express';
import { PersonalController } from '../controllers/personal.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  createCalendarEventSchema,
  updateCalendarEventSchema,
  registerDeviceSchema,
  updateNotificationPreferencesSchema,
  scheduleNotificationSchema,
} from '../validators/calendar_notification.validators.js';
import { updateLectureProgressSchema } from '../validators/personal.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All personal routes require authenticated user
router.use(authenticateUser);

// ─── Calendar Events (CRUD & Range Filter) ───
router.get('/calendar/events', asyncWrapper(PersonalController.listCalendarEvents));
router.get('/calendar', asyncWrapper(PersonalController.listCalendarEvents)); // Legacy alias
router.get('/calendar/events/:id', asyncWrapper(PersonalController.getCalendarEvent));
router.get('/calendar/:id', asyncWrapper(PersonalController.getCalendarEvent)); // Legacy alias

router.post(
  '/calendar/events',
  validateRequest({ body: createCalendarEventSchema }),
  asyncWrapper(PersonalController.createCalendarEvent)
);
router.post(
  '/calendar',
  validateRequest({ body: createCalendarEventSchema }),
  asyncWrapper(PersonalController.createCalendarEvent)
); // Legacy alias

router.patch(
  '/calendar/events/:id',
  validateRequest({ body: updateCalendarEventSchema }),
  asyncWrapper(PersonalController.updateCalendarEvent)
);
router.patch(
  '/calendar/:id',
  validateRequest({ body: updateCalendarEventSchema }),
  asyncWrapper(PersonalController.updateCalendarEvent)
); // Legacy alias

router.delete('/calendar/events/:id', asyncWrapper(PersonalController.deleteCalendarEvent));
router.delete('/calendar/:id', asyncWrapper(PersonalController.deleteCalendarEvent)); // Legacy alias

// ─── Progress Tracking ───
router.post(
  '/progress/lecture',
  validateRequest({ body: updateLectureProgressSchema }),
  asyncWrapper(PersonalController.trackLectureProgress)
);
router.get('/progress/course/:courseId', asyncWrapper(PersonalController.getCourseProgress));

// ─── Notifications (Paginated & Preference-Enforced) ───
router.get('/notifications', asyncWrapper(PersonalController.listNotifications));
router.patch('/notifications/:id/read', asyncWrapper(PersonalController.markRead));
router.post('/notifications/read-all', asyncWrapper(PersonalController.markAllRead));
router.delete('/notifications/:id', asyncWrapper(PersonalController.deleteNotification));

// ─── Notification Preferences ───
router.get('/notifications/preferences', asyncWrapper(PersonalController.getPreferences));
router.patch(
  '/notifications/preferences',
  validateRequest({ body: updateNotificationPreferencesSchema }),
  asyncWrapper(PersonalController.updatePreferences)
);

// ─── Notification Devices (FCM Push Tokens) ───
router.post(
  '/notifications/devices',
  validateRequest({ body: registerDeviceSchema }),
  asyncWrapper(PersonalController.registerDevice)
);
router.delete('/notifications/devices/:token', asyncWrapper(PersonalController.unregisterDevice));

// ─── Asynchronous Scheduled Notification Dispatch ───
router.post(
  '/notifications/schedule',
  validateRequest({ body: scheduleNotificationSchema }),
  asyncWrapper(PersonalController.scheduleNotification)
);

export const personalRoutes = router;
