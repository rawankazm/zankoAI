import { Router } from 'express';
import { PersonalController } from '../controllers/personal.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  createCalendarEventSchema,
  updateCalendarEventSchema,
  updateLectureProgressSchema,
} from '../validators/personal.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All personal routes require authenticated user
router.use(authenticateUser);

// ─── Calendar Events (Ownership Enforced) ───
router.get('/calendar', asyncWrapper(PersonalController.listCalendarEvents));
router.post(
  '/calendar',
  validateRequest({ body: createCalendarEventSchema }),
  asyncWrapper(PersonalController.createCalendarEvent)
);
router.patch(
  '/calendar/:id',
  validateRequest({ body: updateCalendarEventSchema }),
  asyncWrapper(PersonalController.updateCalendarEvent)
);
router.delete('/calendar/:id', asyncWrapper(PersonalController.deleteCalendarEvent));

// ─── Progress Tracking ───
router.post(
  '/progress/lecture',
  validateRequest({ body: updateLectureProgressSchema }),
  asyncWrapper(PersonalController.trackLectureProgress)
);
router.get('/progress/course/:courseId', asyncWrapper(PersonalController.getCourseProgress));

// ─── Notifications (Ownership Enforced) ───
router.get('/notifications', asyncWrapper(PersonalController.listNotifications));
router.patch('/notifications/:id/read', asyncWrapper(PersonalController.markRead));
router.post('/notifications/read-all', asyncWrapper(PersonalController.markAllRead));
router.delete('/notifications/:id', asyncWrapper(PersonalController.deleteNotification));

export const personalRoutes = router;
