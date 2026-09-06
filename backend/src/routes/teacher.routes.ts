import { Router } from 'express';
import { TeacherController } from '../controllers/teacher.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { createCourseSchema, updateGradeSchema } from '../validators/teacher.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// Protected: Requires authentication + teacher or admin role
router.use(authenticateUser);
router.use(requireRole(['teacher', 'admin']));

router.get('/courses', asyncWrapper(TeacherController.getCourses));
router.post(
  '/courses',
  validateRequest({ body: createCourseSchema }),
  asyncWrapper(TeacherController.createCourse)
);
router.get('/courses/:courseId/students', asyncWrapper(TeacherController.getCourseStudents));
router.post(
  '/grade',
  validateRequest({ body: updateGradeSchema }),
  asyncWrapper(TeacherController.gradeStudent)
);

export const teacherRoutes = router;
